// lib/home_page.dart dosyasının tam ve güncel hali

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/settings_service.dart';
import 'dashboard_page.dart';
import 'package:drone_control_v2/l10n/app_localizations.dart';

const String targetSsid = "ESP32_Sensor_GW_AP";
final esp32WebSocketUrl = Uri.parse('ws://192.168.4.1:81');

class DashboardArguments {
  final String productCode;
  final Stream<Map<String, dynamic>> dataStream;
  final Map<int, MotorStatus> initialMotorStatus;

  DashboardArguments({
    required this.productCode,
    required this.dataStream,
    required this.initialMotorStatus,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String? _currentSsid;
  bool _isCheckingConnection = true;
  final SettingsService _settingsService = SettingsService.instance;

  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  bool _isWsConnected = false;

  final StreamController<Map<String, dynamic>> _dataStreamController =
      StreamController.broadcast();

  static const int motorCount = 6;

  final Map<int, MotorStatus> _motorStatus = {
    for (var i = 0; i < motorCount; i++) i: MotorStatus.inactive,
  };
  final Map<int, DateTime> _lastDataTime = {};
  final Duration _inactiveTimeout = const Duration(seconds: 2);
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkWifiAndConnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dataStreamController.close();
    _disconnectFromWebSocket();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWifiAndConnect();
    } else if (state == AppLifecycleState.paused) {
      _disconnectFromWebSocket();
    }
  }

  Future<void> _checkWifiAndConnect() async {
    if (!mounted) return;
    setState(() => _isCheckingConnection = true);

    String? ssid;
    try {
      if (await WiFiForIoTPlugin.isEnabled()) {
        ssid = await WiFiForIoTPlugin.getSSID();
      }
    } catch (e) {
      debugPrint("SSID alınamadı: $e");
    }

    if (!mounted) return;
    setState(() {
      _currentSsid = ssid;
      _isCheckingConnection = false;
    });

    if (_currentSsid == targetSsid && !_isWsConnected) {
      await WiFiForIoTPlugin.forceWifiUsage(true);
      _connectToWebSocket();
    } else if (_currentSsid != targetSsid) {
      _disconnectFromWebSocket();
    }
  }

  void _connectToWebSocket() {
    if (_isWsConnected || !mounted) return;
    try {
      _isWsConnected = true;
      _channel = WebSocketChannel.connect(esp32WebSocketUrl);
      if (mounted) setState(() {});
      _socketSubscription = _channel!.stream.listen(
        _handleWebSocketData,
        onDone: _handleDisconnection,
        onError: (e) => _handleDisconnection(),
        cancelOnError: true,
      );
      _startStatusCheckTimer();
    } catch (e) {
      _handleDisconnection();
    }
  }

  void _handleWebSocketData(dynamic message) {
    if (!mounted) return;
    try {
      final data = jsonDecode(message);
      _dataStreamController.add(data);
      if (data.containsKey('id')) {
        final int transmitterIndex = (data['id'] as int) - 1;
        if (transmitterIndex >= 0 && transmitterIndex < motorCount) {
          _lastDataTime[transmitterIndex] = DateTime.now();
          final double mag = (data['mag'] as num).toDouble();
          MotorStatus newStatus;
          if (mag.abs() > _settingsService.errorThreshold) {
            newStatus = MotorStatus.outOfBounds;
          } else if (mag.abs() > _settingsService.warningThreshold) {
            newStatus = MotorStatus.warning;
          } else {
            newStatus = MotorStatus.normal;
          }
          if (_motorStatus[transmitterIndex] != newStatus) {
            setState(() => _motorStatus[transmitterIndex] = newStatus);
          }
        }
      }
    } catch (e) {
      // Hatalı JSON
    }
  }

  void _startStatusCheckTimer() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      bool changed = false;
      final now = DateTime.now();
      for (int i = 0; i < motorCount; i++) {
        if (_motorStatus[i] != MotorStatus.inactive &&
            now.difference(_lastDataTime[i] ?? DateTime(1970)) >
                _inactiveTimeout) {
          _motorStatus[i] = MotorStatus.inactive;
          changed = true;
        }
      }
      if (changed) setState(() {});
    });
  }

  void _handleDisconnection() {
    if (mounted) {
      _disconnectFromWebSocket();
      if (_currentSsid == targetSsid) {
        Future.delayed(const Duration(seconds: 2), _checkWifiAndConnect);
      }
    }
  }

  void _disconnectFromWebSocket() {
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _statusCheckTimer?.cancel();
    if (mounted && _isWsConnected) {
      setState(() {
        _isWsConnected = false;
        _channel = null;
        _lastDataTime.clear();
        for (var key in _motorStatus.keys) {
          _motorStatus[key] = MotorStatus.inactive;
        }
      });
    }
  }

  Future<void> _navigateToWifiSelection() async {
    await Navigator.pushNamed(context, '/wifi_selection');
    _checkWifiAndConnect();
  }

  Future<void> _scanAndNavigateToDashboard() async {
    final result = await Navigator.pushNamed(context, '/product_code');

    if (result != null && result is String && mounted) {
      final String productCode = result;
      Navigator.pushNamed(
        context,
        '/dashboard',
        arguments: DashboardArguments(
          productCode: productCode,
          dataStream: _dataStreamController.stream,
          initialMotorStatus: Map.from(_motorStatus),
        ),
      );
    }
  }
  
  // ---------- DEĞİŞİKLİK 1: `build` METODU GÜNCELLENDİ ----------
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    bool isConnected = _currentSsid == targetSsid && _isWsConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homePageTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: l10n.savedSessionsTooltip,
            onPressed: () => Navigator.pushNamed(context, '/saved_sessions'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTooltip,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // Bu özellik, elemanlar arasında boşluk bırakarak onları dikeyde dağıtır.
          // Üstteki en üste, alttaki en alta, ortadaki de tam ortaya gelir.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. Üst Kısım: Durum Paneli
            _buildStatusPanel(l10n),
            
            // 2. Orta Kısım: Motor Durumları (Büyütülmüş ve ortalanmış)
            // Sadece Wi-Fi'ye bağlıyken gösterilir.
            if (_currentSsid == targetSsid)
              _buildTransmitterStatusPanel()
            else
              // Wi-Fi bağlı değilken orta kısmın boş kalmaması için boş bir widget ekliyoruz.
              // Bu, alttaki butonların yerinin kaymasını engeller.
              const SizedBox(),

            // 3. Alt Kısım: Butonlar
            // İki butonu bir arada tutmak için kendi Column'larına aldık.
            Column(
              children: [
                _buildConnectButton(l10n),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(l10n.proceedToScanButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isConnected ? Colors.cyanAccent : Colors.grey[800],
                    foregroundColor: isConnected ? Colors.black : Colors.white54,
                    minimumSize: const Size(double.infinity, 50),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: isConnected ? _scanAndNavigateToDashboard : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel(AppLocalizations l10n) {
    String title, subtitle;
    Color cardColor;
    IconData icon;
    Color iconColor;

    if (_isCheckingConnection) {
      title = l10n.statusChecking;
      subtitle = l10n.statusPleaseWait;
      cardColor = Colors.blue.withOpacity(0.3);
      icon = Icons.sync;
      iconColor = Colors.blueAccent;
    } else if (_currentSsid == targetSsid) {
      title = l10n.statusConnectedToDevice;
      subtitle =
          _isWsConnected ? l10n.statusDataStreamActive : l10n.statusWaitingForData;
      cardColor = Colors.green.withOpacity(0.3);
      icon = Icons.check_circle;
      iconColor = Colors.greenAccent;
    } else {
      title = l10n.statusNotConnectedToDevice;
      subtitle = l10n.statusConnectToWifiPrompt;
      cardColor = Colors.orange.withOpacity(0.3);
      icon = Icons.wifi_off_rounded;
      iconColor = Colors.orangeAccent;
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (_isCheckingConnection ||
                (_currentSsid == targetSsid && !_isWsConnected))
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(),
              )
            else
              Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // lib/home_page.dart dosyasındaki bu fonksiyonu güncelleyin

Widget _buildTransmitterStatusPanel() {
  // Dil dosyalarından metinleri almak için l10n nesnesini alıyoruz.
  final l10n = AppLocalizations.of(context)!;
  final textTheme = Theme.of(context).textTheme;

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      // DEĞİŞİKLİK: Başlık ve motorları dikeyde sıralamak için Column ekledik.
      child: Column(
        mainAxisSize: MainAxisSize.min, // İçeriğe göre boyutlanmasını sağlar.
        children: [
          // YENİ: Başlık metni
          Text(
            l10n.motorStatusTitle, // Bu metni dil dosyalarına ekleyeceğiz.
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // YENİ: Başlık ile içerik arasına görsel bir ayırıcı
          const Divider(thickness: 1.0),
          const SizedBox(height: 16),

          // Mevcut motor göstergeleri (Wrap widget'ı)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24.0,
            runSpacing: 24.0,
            children: List.generate(motorCount, (index) {
              final status = _motorStatus[index]!;
              Color color;
              switch (status) {
                case MotorStatus.normal:      color = Colors.greenAccent; break;
                case MotorStatus.warning:     color = Colors.yellowAccent; break;
                case MotorStatus.outOfBounds: color = Colors.redAccent; break;
                case MotorStatus.inactive:    color = Colors.grey[700]!; break;
              }
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        if (status != MotorStatus.inactive)
                          BoxShadow(
                            color: color.withOpacity(0.7),
                            blurRadius: 10.0,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "M${index + 1}",
                    style: textTheme.titleMedium?.copyWith(
                      color: status != MotorStatus.inactive
                          ? Colors.white
                          : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildConnectButton(AppLocalizations l10n) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.wifi_find_rounded),
      label: Text(l10n.connectToDeviceWifiButton),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: _isCheckingConnection ? null : _navigateToWifiSelection,
    );
  }
}