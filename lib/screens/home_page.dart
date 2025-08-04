// lib/screens/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';

const String targetSsid = "ESP32_Sensor_GW_AP";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isScanning = false;
  List<WifiNetwork> _wifiList = [];
  String? _currentSsid;

  @override
  void initState() {
    super.initState();
    _getCurrentSsid();
  }

  Future<void> _getCurrentSsid() async {
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
      });
    }
  }

  Future<void> _scanForWifi() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _wifiList = [];
    });

    await WiFiForIoTPlugin.setEnabled(true);
    List<WifiNetwork> scanResult = await WiFiForIoTPlugin.loadWifiList();

    if (mounted) {
      setState(() {
        _wifiList = scanResult;
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToWifi(WifiNetwork network) async {
    if (network.ssid == targetSsid) {
      await WiFiForIoTPlugin.connect(
        targetSsid,
        password: "vibrationsensor",
        security: NetworkSecurity.WPA,
      );
      await _getCurrentSsid();
    }
  }

  // --- YENİ FONKSİYON ---
  // Ayarlar sayfasına gitmek için.
  void _navigateToSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  @override
  Widget build(BuildContext context) {
    bool isConnectedToTarget = _currentSsid == targetSsid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bağlantı ve Ayarlar'),
        actions: [
          // --- YENİ BUTON EKLENDİ ---
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
            onPressed: _navigateToSettings,
          ),
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _scanForWifi,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusPanel(isConnectedToTarget),
          const Divider(height: 1),
          Expanded(
            child: _wifiList.isEmpty && !_isScanning
                ? const Center(child: Text("Ağları görmek için tarama yapın."))
                : ListView.builder(
                    itemCount: _wifiList.length,
                    itemBuilder: (context, index) {
                      final network = _wifiList[index];
                      IconData signalIcon;
                      if (network.level! > -50) {
                        signalIcon = Icons.wifi_sharp;
                      } else if (network.level! > -70) {
                        signalIcon = Icons.wifi_2_bar_sharp;
                      } else {
                        signalIcon = Icons.wifi_1_bar_sharp;
                      }

                      return ListTile(
                        leading: Icon(signalIcon),
                        title: Text(network.ssid ?? "İsimsiz Ağ"),
                        subtitle: Text("Sinyal: ${network.level} dBm"),
                        trailing: network.ssid == targetSsid
                            ? ElevatedButton(
                                onPressed: () => _connectToWifi(network),
                                child: const Text("Bağlan"),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          _buildNavigateButton(isConnectedToTarget),
        ],
      ),
    );
  }

  Widget _buildStatusPanel(bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: isConnected
          ? Colors.green.withOpacity(0.2)
          : Colors.red.withOpacity(0.2),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.error,
            color: isConnected ? Colors.green[200] : Colors.red[200],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isConnected
                  ? "'$targetSsid' ağına bağlısınız."
                  : "Grafiği görmek için '$targetSsid' ağına bağlanın.",
              style: TextStyle(
                color: isConnected ? Colors.green[100] : Colors.red[100],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigateButton(bool isConnected) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.bar_chart_rounded),
        label: const Text('Grafiği Görüntüle'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isConnected ? Colors.greenAccent : Colors.grey[800],
          foregroundColor: isConnected ? Colors.black : Colors.white54,
          minimumSize: const Size(double.infinity, 50),
        ),
        onPressed: isConnected
            ? () async {
                await Navigator.pushNamed(context, '/dashboard');
                print(
                  "Ana sayfaya dönüldü, Wi-Fi durumu yeniden kontrol ediliyor...",
                );
                _getCurrentSsid();
              }
            : null,
      ),
    );
  }
}
