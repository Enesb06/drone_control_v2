import 'package:flutter/material.dart';
import 'package:drone_control_v2/services/settings_service.dart';
// Bu import, .arb dosyalarını oluşturduktan sonra hata vermeyecektir.
import 'package:drone_control_v2/l10n/app_localizations.dart';


class LocaleProvider with ChangeNotifier {
  Locale? _locale;
  final SettingsService _settingsService = SettingsService.instance;

  LocaleProvider() {
    // Servisten kayıtlı dil kodunu alıp başlangıç locale'ini ayarla
    final langCode = _settingsService.languageCode;
    if (langCode.isNotEmpty) {
      _locale = Locale(langCode);
    }
  }

  Locale? get locale => _locale;

  void setLocale(Locale newLocale) {
    // Sadece desteklenen dillerin ayarlanmasına izin ver
    if (!AppLocalizations.supportedLocales.contains(newLocale)) return;

    _locale = newLocale;
    _settingsService.setLanguageCode(newLocale.languageCode).then((_) {
      notifyListeners(); // Arayüzü güncelle
    });
  }
}