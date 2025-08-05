// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Import color picker
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService.instance;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _warningController;
  late TextEditingController _errorController;
  late List<Color> _currentColors;

  @override
  void initState() {
    super.initState();
    _warningController = TextEditingController(
      text: _settingsService.warningThreshold.toString(),
    );
    _errorController = TextEditingController(
      text: _settingsService.errorThreshold.toString(),
    );
    // Renklerin bir kopyasını alarak state'de tut
    _currentColors = List<Color>.from(_settingsService.transmitterColors);
  }

  @override
  void dispose() {
    _warningController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final double warningValue = double.tryParse(_warningController.text) ?? 0;
    final double errorValue = double.tryParse(_errorController.text) ?? 0;

    if (warningValue >= errorValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uyarı eşiği, Hata eşiğinden küçük olmalıdır!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Eşikleri kaydet
    await _settingsService.setWarningThreshold(warningValue);
    await _settingsService.setErrorThreshold(errorValue);

    // Renkleri kaydet
    for (int i = 0; i < _currentColors.length; i++) {
      await _settingsService.setTransmitterColor(i, _currentColors[i]);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ayarlar başarıyla kaydedildi!'),
        backgroundColor: Colors.green,
      ),
    );

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  // Renk seçici dialog'unu gösteren fonksiyon
  void _showColorPicker(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verici ${index + 1} Rengini Seçin'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _currentColors[index],
            onColorChanged: (color) {
              setState(() => _currentColors[index] = color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Tamam'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Genel Ayarlar'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Titreşim Eşikleri',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(color: Colors.cyanAccent),
                const SizedBox(height: 10),
                _buildTextFieldTile(
                  title: 'Uyarı Eşiği (Sarı)',
                  controller: _warningController,
                ),
                const SizedBox(height: 16),
                _buildTextFieldTile(
                  title: 'Hata Eşiği (Kırmızı)',
                  controller: _errorController,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Grafik Renkleri',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(color: Colors.cyanAccent),
                const SizedBox(height: 10),
                // Renk seçicileri oluştur
                ...List.generate(
                  4,
                  (index) => _buildColorPickerTile(
                    index: index,
                    title: 'Verici ${index + 1} Rengi',
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Tüm Ayarları Kaydet'),
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
      ),
    );
  }

  Widget _buildTextFieldTile({
    required String title,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (value) => (value == null || value.isEmpty)
              ? 'Bu alan boş bırakılamaz'
              : null,
          style: const TextStyle(fontSize: 18, color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).primaryColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPickerTile({required int index, required String title}) {
    return Card(
      color: Theme.of(context).primaryColor,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _currentColors[index],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: ElevatedButton(
          child: const Text('Değiştir'),
          onPressed: () => _showColorPicker(index),
        ),
      ),
    );
  }
}
