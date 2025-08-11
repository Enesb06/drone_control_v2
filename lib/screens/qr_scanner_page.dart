import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:drone_control_v2/l10n/app_localizations.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanCompleted = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanCompleted) return;

    final String? code = capture.barcodes.first.rawValue;
    if (code != null) {
      setState(() {
        _isScanCompleted = true;
      });
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.qrScannerPageTitle),
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 4),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}