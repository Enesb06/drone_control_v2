import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'home_page.dart';
import 'package:drone_control_v2/l10n/app_localizations.dart';

class WifiSelectionPage extends StatefulWidget {
  const WifiSelectionPage({super.key});

  @override
  State<WifiSelectionPage> createState() => _WifiSelectionPageState();
}

class _WifiSelectionPageState extends State<WifiSelectionPage> {
  bool _isScanning = false;
  List<WifiNetwork> _wifiList = [];
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _scanForWifi();
  }

  Future<void> _scanForWifi() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    try {
      await WiFiForIoTPlugin.setEnabled(true);
      final scanResult = await WiFiForIoTPlugin.loadWifiList();
      scanResult.sort((a, b) => b.level!.compareTo(a.level!));
      if (mounted) setState(() => _wifiList = scanResult);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Wi-Fi tarama hatası: $e")));
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToWifi(WifiNetwork network) async {
    final l10n = AppLocalizations.of(context)!;
    if (network.ssid != targetSsid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.onlyConnectToTargetSsid(targetSsid)),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isConnecting = true);

    bool success = false;
    try {
      await WiFiForIoTPlugin.connect(
        targetSsid,
        password: "vibrationsensor",
        security: NetworkSecurity.WPA,
      );
      success = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.connectionError(e.toString()))));
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
        if (success) {
          Navigator.pop(context, true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wifiSelectionPageTitle),
        actions: [
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
            tooltip: l10n.refreshNetworksTooltip,
            onPressed: _scanForWifi,
          ),
        ],
      ),
      body: _isConnecting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.connectingToNetwork),
                ],
              ),
            )
          : _wifiList.isEmpty && !_isScanning
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 60, color: Colors.white38),
                      const SizedBox(height: 20),
                      Text(l10n.noWifiNetworksFound),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.rescanButton),
                        onPressed: _scanForWifi,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: _wifiList.length,
                  itemBuilder: (context, index) {
                    final network = _wifiList[index];
                    if (network.ssid == null || network.ssid!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final bool isTargetNetwork = network.ssid == targetSsid;
                    IconData signalIcon;
                    if (network.level! > -50) {
                      signalIcon = Icons.wifi_sharp;
                    } else if (network.level! > -70) {
                      signalIcon = Icons.wifi_2_bar_sharp;
                    } else {
                      signalIcon = Icons.wifi_1_bar_sharp;
                    }

                    return Card(
                      elevation: isTargetNetwork ? 4 : 1,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      color: isTargetNetwork
                          ? Colors.cyan.withOpacity(0.2)
                          : Theme.of(context).cardColor,
                      child: ListTile(
                        leading: Icon(
                          signalIcon,
                          color: isTargetNetwork
                              ? Colors.cyanAccent
                              : Colors.white70,
                        ),
                        title: Text(
                          network.ssid!,
                          style: TextStyle(
                            fontWeight: isTargetNetwork
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isTargetNetwork
                                ? Colors.cyanAccent
                                : Colors.white,
                          ),
                        ),
                        subtitle: Text(l10n.signalStrength(network.level!)),
                        trailing: isTargetNetwork
                            ? ElevatedButton(
                                onPressed: _isConnecting
                                    ? null
                                    : () => _connectToWifi(network),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(l10n.connectButton),
                              )
                            : null,
                        onTap: isTargetNetwork
                            ? () => _connectToWifi(network)
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}