import 'package:flutter/material.dart';
import 'qr_scanner_page.dart';
import 'package:drone_control_v2/l10n/app_localizations.dart';

class ProductCodePage extends StatefulWidget {
  const ProductCodePage({super.key});

  @override
  State<ProductCodePage> createState() => _ProductCodePageState();
}

class _ProductCodePageState extends State<ProductCodePage> {
  final _controller = TextEditingController();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final isNotEmpty = _controller.text.trim().isNotEmpty;
      if (isNotEmpty != _isButtonEnabled) {
        setState(() {
          _isButtonEnabled = isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openQRScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerPage()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      _controller.text = result;
    }
  }

  void _startTest() {
    if (!_isButtonEnabled) return;
    Navigator.pushReplacementNamed(
      context,
      '/home',
      arguments: _controller.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productCodePageTitle),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.welcomeMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 80,
                color: Colors.cyanAccent.withOpacity(0.8),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.productCodePrompt,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: l10n.productIDFieldLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: l10n.scanQRCodeTooltip,
                    onPressed: _openQRScanner,
                    color: Colors.cyanAccent,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.startTestButton),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor:
                      _isButtonEnabled ? Colors.greenAccent : Colors.grey[800],
                  foregroundColor:
                      _isButtonEnabled ? Colors.black : Colors.white54,
                ),
                onPressed: _isButtonEnabled ? _startTest : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}