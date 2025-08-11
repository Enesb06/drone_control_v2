import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // Eşik ayarları için anahtarlar
  static const String _warningThresholdKey = 'warning_threshold';
  static const String _errorThresholdKey = 'error_threshold';
  
  // DİL AYARI İÇİN EKLENEN ANAHTAR
  static const String _languageCodeKey = 'language_code';

  // Renk ayarları için anahtar öneki
  static const String colorKeyPrefix = 'transmitter_color';

  // Varsayılan değerler
  static const double _defaultWarningThreshold = 2.0;
  static const double _defaultErrorThreshold = 4.0;
  static final List<Color> _defaultColors = [
    Colors.cyan,
    Colors.pinkAccent,
    Colors.amberAccent,
    Colors.lightGreenAccent,
  ];

  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  late SharedPreferences _prefs;

  // Değerleri tutacak değişkenler
  late double warningThreshold;
  late double errorThreshold;
  late List<Color> transmitterColors;
  
  // DİL AYARI İÇİN EKLENEN ÖZELLİK
  late String languageCode;

  // Servisi başlatan ve tüm kayıtlı değerleri yükleyen fonksiyon
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    // Eşikleri yükle
    warningThreshold =
        _prefs.getDouble(_warningThresholdKey) ?? _defaultWarningThreshold;
    errorThreshold =
        _prefs.getDouble(_errorThresholdKey) ?? _defaultErrorThreshold;
    
    // DİL AYARI İÇİN EKLENEN KOD
    // Kayıtlı dil kodunu yükle, yoksa varsayılan 'tr' olsun
    languageCode = _prefs.getString(_languageCodeKey) ?? 'tr';

    // Renkleri yükle
    transmitterColors = [];
    for (int i = 0; i < 4; i++) {
      final int? savedColorValue = _prefs.getInt('$colorKeyPrefix$i');
      if (savedColorValue != null) {
        transmitterColors.add(Color(savedColorValue));
      } else {
        transmitterColors.add(_defaultColors[i]);
      }
    }
  }

  // Eşikleri kaydetme fonksiyonları
  Future<void> setWarningThreshold(double value) async {
    warningThreshold = value;
    await _prefs.setDouble(_warningThresholdKey, value);
  }

  Future<void> setErrorThreshold(double value) async {
    errorThreshold = value;
    await _prefs.setDouble(_errorThresholdKey, value);
  }

  // DİL AYARI İÇİN EKLENEN METOT
  Future<void> setLanguageCode(String code) async {
    languageCode = code;
    await _prefs.setString(_languageCodeKey, code);
  }

  // Belirli bir vericinin rengini kaydeder
  Future<void> setTransmitterColor(int index, Color color) async {
    if (index < 0 || index >= transmitterColors.length) return;
    transmitterColors[index] = color;
    await _prefs.setInt('$colorKeyPrefix$index', color.value);
  }
}