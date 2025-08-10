// lib/screens/home_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/settings_service.dart';
import '../screens/dashboard_page.dart'; // Dashboard'un Enum'larını kullanmak için

const String targetSsid = "ESP32_Sensor_GW_AP";
final esp32WebSocketUrl = Uri.parse('ws://192.168.4.1:81');

// Dashboard'a argüman olarak geçilecek veri paketi
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

  // --- MERKEZİ STATE YÖNETİMİ ---
  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  bool _isWsConnected = false;

  // Dashboard'a gönderilecek olan StreamController
  final StreamController<Map<String, dynamic>> _dataStreamController =
      StreamController.broadcast();

  final Map<int, MotorStatus> _motorStatus = {
    for (var i = 0; i < 4; i++) i: MotorStatus.inactive,
  };
  final Map<int, DateTime> _lastDataTime = {};
  final Duration _inactiveTimeout = const Duration(seconds: 2);
  Timer? _statusCheckTimer;
  // --- MERKEZİ STATE SONU ---

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

      if (mounted) setState(() {}); // Buton durumunu güncellemek için

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
      _dataStreamController.add(data); // Veriyi Dashboard'a yolla

      if (data.containsKey('id')) {
        final int transmitterIndex = (data['id'] as int) - 1;
        if (transmitterIndex >= 0 && transmitterIndex < 4) {
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
      for (int i = 0; i < 4; i++) {
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

  // --- UI KODLARI ---

  Future<void> _navigateToWifiSelection() async {
    await Navigator.pushNamed(context, '/wifi_selection');
    _checkWifiAndConnect();
  }

  void _navigateToDashboard() {
    final productCode = ModalRoute.of(context)!.settings.arguments as String;
    Navigator.pushNamed(
      context,
      '/dashboard',
      arguments: DashboardArguments(
        productCode: productCode,
        dataStream: _dataStreamController.stream,
        initialMotorStatus: Map.from(
          _motorStatus,
        ), // Mevcut durumun bir kopyasını gönder
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = _currentSsid == targetSsid && _isWsConnected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontrol Paneli'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Kayıtlı Oturumlar',
            onPressed: () => Navigator.pushNamed(context, '/saved_sessions'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusPanel(),
            if (_currentSsid == targetSsid) ...[
              const SizedBox(height: 16),
              _buildTransmitterStatusPanel(),
            ],
            const Spacer(),
            _buildConnectButton(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart_rounded),
              label: const Text('Grafiği Görüntüle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected
                    ? Colors.greenAccent
                    : Colors.grey[800],
                foregroundColor: isConnected ? Colors.black : Colors.white54,
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: isConnected ? _navigateToDashboard : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    String title, subtitle;
    Color cardColor;
    IconData icon;
    Color iconColor;

    if (_isCheckingConnection) {
      title = "Kontrol Ediliyor...";
      subtitle = "Lütfen bekleyin.";
      cardColor = Colors.blue.withOpacity(0.3);
      icon = Icons.sync;
      iconColor = Colors.blueAccent;
    } else if (_currentSsid == targetSsid) {
      title = "Cihaza Bağlı";
      subtitle = _isWsConnected ? "Veri akışı aktif." : "Veri bekleniyor...";
      cardColor = Colors.green.withOpacity(0.3);
      icon = Icons.check_circle;
      iconColor = Colors.greenAccent;
    } else {
      title = "Cihaza Bağlı Değil";
      subtitle = "Lütfen cihazın Wi-Fi ağına bağlanın.";
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

  Widget _buildTransmitterStatusPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(4, (index) {
            final status = _motorStatus[index]!;
            Color color;
            switch (status) {
              case MotorStatus.normal:
                color = Colors.greenAccent;
                break;
              case MotorStatus.warning:
                color = Colors.yellowAccent;
                break;
              case MotorStatus.outOfBounds:
                color = Colors.redAccent;
                break;
              case MotorStatus.inactive:
                color = Colors.grey[700]!;
                break;
            }
            return Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      if (status != MotorStatus.inactive)
                        BoxShadow(
                          color: color.withOpacity(0.7),
                          blurRadius: 6.0,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "V${index + 1}",
                  style: TextStyle(
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
      ),
    );
  }

  Widget _buildConnectButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.wifi_find_rounded),
      label: const Text('Cihaz Wi-Fi Ağına Bağlan'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: _isCheckingConnection ? null : _navigateToWifiSelection,
    );
  }
}
