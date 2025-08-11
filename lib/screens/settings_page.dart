import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../services/settings_service.dart';
import 'package:drone_control_v2/l10n/app_localizations.dart';

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
    _currentColors = List<Color>.from(_settingsService.transmitterColors);
  }

  @override
  void dispose() {
    _warningController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final double warningValue = double.tryParse(_warningController.text) ?? 0;
    final double errorValue = double.tryParse(_errorController.text) ?? 0;

    if (warningValue >= errorValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.warningThresholdMustBeLower),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _settingsService.setWarningThreshold(warningValue);
    await _settingsService.setErrorThreshold(errorValue);

    for (int i = 0; i < _currentColors.length; i++) {
      await _settingsService.setTransmitterColor(i, _currentColors[i]);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.settingsSavedSuccessfully),
        backgroundColor: Colors.green,
      ),
    );

    if (mounted) {
      FocusScope.of(context).unfocus();
      Navigator.of(context).pop();
    }
  }

  void _showColorPicker(int index) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectMotorColorTitle(index + 1)),
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
            child: Text(l10n.okButton),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsPageTitle),
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
                  'Dil / Language',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(color: Colors.cyanAccent),
                DropdownButtonFormField<String>(
                  value: localeProvider.locale?.languageCode ?? 'tr',
                  items: const [
                    DropdownMenuItem(value: 'tr', child: Text('Türkçe 🇹🇷')),
                    DropdownMenuItem(value: 'en', child: Text('English 🇬🇧')),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      localeProvider.setLocale(Locale(newValue));
                    }
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).primaryColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.vibrationThresholds,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(color: Colors.cyanAccent),
                const SizedBox(height: 10),
                _buildTextFieldTile(
                  title: l10n.warningThresholdSetting,
                  controller: _warningController,
                  l10n: l10n,
                ),
                const SizedBox(height: 16),
                _buildTextFieldTile(
                  title: l10n.errorThresholdSetting,
                  controller: _errorController,
                  l10n: l10n,
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.graphColors,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(color: Colors.cyanAccent),
                const SizedBox(height: 10),
                ...List.generate(
                  4,
                  (index) => _buildColorPickerTile(
                    index: index,
                    title: l10n.motorColorSetting(index + 1),
                    l10n: l10n,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(l10n.saveAllSettingsButton),
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
    required AppLocalizations l10n,
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
          validator: (value) =>
              (value == null || value.isEmpty) ? l10n.fieldCannotBeEmpty : null,
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

  Widget _buildColorPickerTile(
      {required int index, required String title, required AppLocalizations l10n}) {
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
          child: Text(l10n.changeButton),
          onPressed: () => _showColorPicker(index),
        ),
      ),
    );
  }
}