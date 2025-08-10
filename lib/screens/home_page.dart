// lib/screens/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';

// Bu sabit dışarıdan erişim için hala burada kalabilir.
const String targetSsid = "ESP32_Sensor_GW_AP";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _currentSsid;
  bool _isCheckingConnection = true;
  bool _isPreparingForDashboard = false;

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında mevcut bağlantıyı kontrol et
    _getCurrentSsid();
  }

  Future<void> _getCurrentSsid() async {
    // Kontrol başladığında göstergeyi aktifleştir
    if (mounted) setState(() => _isCheckingConnection = true);
    String? currentSsid;
    try {
      bool isWifiEnabled = await WiFiForIoTPlugin.isEnabled();
      if (isWifiEnabled) {
        currentSsid = await WiFiForIoTPlugin.getSSID();
      } else {
        currentSsid = null;
      }
    } catch (e) {
      print("SSID alınırken hata oluştu: $e");
      currentSsid = null;
    }
    if (mounted) {
      setState(() {
        _currentSsid = currentSsid;
        // Kontrol bittiğinde göstergeyi kapat
        _isCheckingConnection = false;
      });
    }
  }

  // --- YENİ ---
  // Wi-Fi seçim sayfasına gitmek için yeni fonksiyon
  Future<void> _navigateToWifiSelection() async {
    // WifiSelectionPage'e git ve bir sonuç bekle
    final result = await Navigator.pushNamed(context, '/wifi_selection');

    // Eğer WifiSelectionPage'den 'true' sonucuyla dönüldüyse
    // (yani bağlantı başarılı olduysa), mevcut SSID'yi tekrar kontrol et
    if (result == true && mounted) {
      await _getCurrentSsid();
    }
  }

  void _navigateToSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  void _navigateToSavedSessions() {
    Navigator.pushNamed(context, '/saved_sessions');
  }

  @override
  Widget build(BuildContext context) {
    bool isConnectedToTarget = _currentSsid == targetSsid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontrol Paneli'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Kayıtlı Oturumlar',
            onPressed: _navigateToSavedSessions,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      // --- DEĞİŞTİ ---
      // Body artık çok daha basit
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusPanel(isConnectedToTarget),
            const Spacer(), // Boşluk ekleyerek butonları aşağı iter
            _buildConnectButton(),
            const SizedBox(height: 16),
            _buildNavigateButton(isConnectedToTarget),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel(bool isConnected) {
    return Card(
      color: isConnected
          ? Colors.green.withOpacity(0.3)
          : Colors.orange.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (_isCheckingConnection)
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(),
              )
            else
              Icon(
                isConnected ? Icons.check_circle : Icons.wifi_off_rounded,
                color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                size: 32,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? "Cihaza Bağlı" : "Cihaza Bağlı Değil",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isConnected
                        ? "Teste başlamak için hazırsınız."
                        : "Lütfen cihazın Wi-Fi ağına bağlanın.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- YENİ BUTON ---
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

  Widget _buildNavigateButton(bool isConnected) {
    final productCode = ModalRoute.of(context)!.settings.arguments as String;

    return ElevatedButton.icon(
      icon: _isPreparingForDashboard
          ? Container(
              width: 24,
              height: 24,
              padding: const EdgeInsets.all(2.0),
              child: const CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 3,
              ),
            )
          : const Icon(Icons.bar_chart_rounded),
      label: Text(
        _isPreparingForDashboard ? 'Hazırlanıyor...' : 'Grafiği Görüntüle',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isConnected ? Colors.greenAccent : Colors.grey[800],
        foregroundColor: isConnected ? Colors.black : Colors.white54,
        minimumSize: const Size(double.infinity, 50),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      onPressed: (isConnected && !_isPreparingForDashboard)
          ? () async {
              setState(() => _isPreparingForDashboard = true);
              try {
                // Bu adımlar önemli
                await WiFiForIoTPlugin.forceWifiUsage(true);
                await Future.delayed(const Duration(milliseconds: 500));

                await Navigator.pushNamed(
                  context,
                  '/dashboard',
                  arguments: productCode,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bağlantı hatası: $e')),
                  );
                }
              } finally {
                // Dashboard sayfasından geri dönüldüğünde çalışacak kod
                await WiFiForIoTPlugin.forceWifiUsage(false);
                await _getCurrentSsid(); // Bağlantı durumunu yenile
                if (mounted) {
                  setState(() => _isPreparingForDashboard = false);
                }
              }
            }
          : null,
    );
  }
}
