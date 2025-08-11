// lib/services/settings_service.dart dosyasının tam ve güncel hali

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _warningThresholdKey = 'warning_threshold';
  static const String _errorThresholdKey = 'error_threshold';
  static const String _languageCodeKey = 'language_code';
  static const String colorKeyPrefix = 'transmitter_color';

  // DEĞİŞTİ: Motor sayısı 6'ya çıkarıldı.
  static const int motorCount = 6;
  
  static const double _defaultWarningThreshold = 2.0;
  static const double _defaultErrorThreshold = 4.0;
  // DEĞİŞTİ: 6 motor için 6 varsayılan renk tanımlandı.
  static final List<Color> _defaultColors = [
    Colors.cyan,
    Colors.pinkAccent,
    Colors.amberAccent,
    Colors.lightGreenAccent,
    Colors.orange,
    Colors.purpleAccent,
  ];

  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  late SharedPreferences _prefs;

  late double warningThreshold;
  late double errorThreshold;
  late List<Color> transmitterColors;
  late String languageCode;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    warningThreshold =
        _prefs.getDouble(_warningThresholdKey) ?? _defaultWarningThreshold;
    errorThreshold =
        _prefs.getDouble(_errorThresholdKey) ?? _defaultErrorThreshold;
    languageCode = _prefs.getString(_languageCodeKey) ?? 'tr';

    // DEĞİŞTİ: Renkler 6 motor için yükleniyor.
    transmitterColors = [];
    for (int i = 0; i < motorCount; i++) {
      final int? savedColorValue = _prefs.getInt('$colorKeyPrefix$i');
      if (savedColorValue != null) {
        transmitterColors.add(Color(savedColorValue));
      } else {
        transmitterColors.add(_defaultColors[i]);
      }
    }
  }

  Future<void> setWarningThreshold(double value) async {
    warningThreshold = value;
    await _prefs.setDouble(_warningThresholdKey, value);
  }

  Future<void> setErrorThreshold(double value) async {
    errorThreshold = value;
    await _prefs.setDouble(_errorThresholdKey, value);
  }

  Future<void> setLanguageCode(String code) async {
    languageCode = code;
    await _prefs.setString(_languageCodeKey, code);
  }

  Future<void> setTransmitterColor(int index, Color color) async {
    if (index < 0 || index >= transmitterColors.length) return;
    transmitterColors[index] = color;
    await _prefs.setInt('$colorKeyPrefix$index', color.value);
  }
}