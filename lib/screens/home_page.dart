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

  // *** YENİ DURUM DEĞİŞKENİ EKLENDİ ***
  // Ağ bağlantı işlemi sırasında butona tekrar basılmasını engellemek için.
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _getCurrentSsid();
  }

  Future<void> _getCurrentSsid() async {
    // ... Bu fonksiyon aynı kalıyor ...
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

  // ... _scanForWifi, _connectToWifi, _navigateToSettings fonksiyonları aynı kalıyor ...
  Future<void> _scanForWifi() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    try {
      await WiFiForIoTPlugin.setEnabled(true);
      final scanResult = await WiFiForIoTPlugin.loadWifiList();
      if (mounted) setState(() => _wifiList = scanResult);
    } catch (e) {
      print("Wi-Fi tarama hatası: $e");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToWifi(WifiNetwork network) async {
    if (network.ssid != targetSsid) return;
    setState(
      () => _isConnecting = true,
    ); // Bağlanma işlemi için de kilitleyelim
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Bağlanılıyor..."),
            ],
          ),
        ),
      ),
    );
    try {
      await WiFiForIoTPlugin.connect(
        targetSsid,
        password: "vibrationsensor",
        security: NetworkSecurity.WPA,
      );
    } catch (e) {
      print("Bağlanma hatası: $e");
    } finally {
      if (mounted) Navigator.pop(context);
      await _getCurrentSsid();
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _navigateToSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  @override
  Widget build(BuildContext context) {
    // ... build fonksiyonunun içeriği aynı kalıyor, sadece _buildNavigateButton çağrılıyor ...
    bool isConnectedToTarget = _currentSsid == targetSsid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bağlantı ve Ayarlar'),
        actions: [
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
                      if (network.ssid == null || network.ssid!.isEmpty)
                        return const SizedBox.shrink();
                      IconData signalIcon;
                      if (network.level! > -50)
                        signalIcon = Icons.wifi_sharp;
                      else if (network.level! > -70)
                        signalIcon = Icons.wifi_2_bar_sharp;
                      else
                        signalIcon = Icons.wifi_1_bar_sharp;
                      return ListTile(
                        leading: Icon(signalIcon),
                        title: Text(network.ssid!),
                        subtitle: Text("Sinyal: ${network.level} dBm"),
                        trailing: network.ssid == targetSsid
                            ? ElevatedButton(
                                onPressed: _isConnecting
                                    ? null
                                    : () => _connectToWifi(
                                        network,
                                      ), // Bağlanırken de butonu kilitle
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
    // ... Bu fonksiyon aynı kalıyor ...
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

  // *** BU FONKSİYON ANR ÇÖKMESİNİ ENGELLEMEK İÇİN GÜNCELLENDİ ***
  Widget _buildNavigateButton(bool isConnected) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        icon: _isConnecting
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
        label: Text(_isConnecting ? 'Hazırlanıyor...' : 'Grafiği Görüntüle'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isConnected ? Colors.greenAccent : Colors.grey[800],
          foregroundColor: isConnected ? Colors.black : Colors.white54,
          minimumSize: const Size(double.infinity, 50),
          // İşlem devam ederken butonun rengini değiştirerek pasif olduğunu daha net gösterelim
          disabledBackgroundColor: Colors.grey[600],
        ),
        // Butonu aktif etmek için hem bağlı olmalı hem de başka bir işlem devam etmemeli.
        onPressed: (isConnected && !_isConnecting)
            ? () async {
                setState(() => _isConnecting = true);

                try {
                  print("Ağ bağlantı kuralı oluşturuluyor...");
                  await WiFiForIoTPlugin.connect(
                    targetSsid,
                    password: "vibrationsensor",
                    security: NetworkSecurity.WPA,
                    withInternet: false,
                  );

                  print("Ağ kullanımı Wi-Fi'a zorlanıyor...");
                  await WiFiForIoTPlugin.forceWifiUsage(true);

                  await Future.delayed(const Duration(milliseconds: 500));

                  print("Bağlantı hazır. Grafik sayfasına yönlendiriliyor.");
                  await Navigator.pushNamed(context, '/dashboard');
                } catch (e) {
                  print("Grafik sayfasına geçiş öncesi bağlantı hatası: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bağlantı hatası: $e')),
                    );
                  }
                } finally {
                  // Bu blok, işlem başarılı da olsa hata da alsa HER ZAMAN çalışır.
                  // Böylece kilitlenmiş bir durumda kalmayız.
                  print(
                    "Ana sayfaya dönüldü, Wi-Fi durumu yeniden kontrol ediliyor...",
                  );
                  await WiFiForIoTPlugin.forceWifiUsage(
                    false,
                  ); // Ağ zorlamasını kapatalım
                  await _getCurrentSsid();
                  if (mounted) {
                    setState(() => _isConnecting = false);
                  }
                }
              }
            : null, // Koşul sağlanmıyorsa butonu pasif yap.
      ),
    );
  }
}
