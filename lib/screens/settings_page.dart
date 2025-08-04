// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Input formatters için gerekli
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService.instance;

  // Metin kutularını kontrol etmek için controller'lar
  late TextEditingController _warningController;
  late TextEditingController _errorController;

  // Formu doğrulamak için bir key
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Controller'ları başlangıç değerleriyle oluştur
    _warningController = TextEditingController(
      text: _settingsService.warningThreshold.toString(),
    );
    _errorController = TextEditingController(
      text: _settingsService.errorThreshold.toString(),
    );
  }

  @override
  void dispose() {
    // Sayfa kapandığında controller'ları temizle
    _warningController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    // Önce formun geçerli olup olmadığını kontrol et (örneğin boş bırakılmış mı?)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Metinleri sayıya çevir
    final double warningValue = double.tryParse(_warningController.text) ?? 0;
    final double errorValue = double.tryParse(_errorController.text) ?? 0;

    // Mantıksal kontrol: Uyarı eşiği, hata eşiğinden küçük olmalı
    if (warningValue >= errorValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uyarı eşiği, Hata eşiğinden küçük olmalıdır!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _settingsService.setWarningThreshold(warningValue);
    _settingsService.setErrorThreshold(errorValue);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ayarlar başarıyla kaydedildi!'),
        backgroundColor: Colors.green,
      ),
    );

    // Klavyeyi kapat ve bir önceki sayfaya dön
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Titreşim Eşik Ayarları'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          // Form widget'ı ile tüm metin kutularını sarmala
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextFieldTile(
                title: 'Uyarı Eşiği (Sarı)',
                subtitle:
                    'Bu değerin üzerindeki titreşimler "Uyarı" olarak işaretlenir.',
                controller: _warningController,
              ),
              const SizedBox(height: 24),
              _buildTextFieldTile(
                title: 'Hata Eşiği (Kırmızı)',
                subtitle:
                    'Bu değerin üzerindeki titreşimler "Hata" olarak işaretlenir.',
                controller: _errorController,
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Ayarları Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _saveSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- YENİ WIDGET: _buildTextFieldTile ---
  Widget _buildTextFieldTile({
    required String title,
    required String subtitle,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            // Sadece ondalıklı sayı klavyesini göster
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Sadece rakam ve bir tane nokta girilmesine izin ver
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            // Doğrulama (validation) kuralı: Boş olamaz
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Bu alan boş bırakılamaz';
              }
              return null;
            },
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: 'Değer girin',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
