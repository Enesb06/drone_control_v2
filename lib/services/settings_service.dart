// lib/services/settings_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // Eşik ayarları için anahtarlar
  static const String _warningThresholdKey = 'warning_threshold';
  static const String _errorThresholdKey = 'error_threshold';

  // Renk ayarları için anahtar öneki
  static const String _colorKeyPrefix = 'transmitter_color_';

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

  // Servisi başlatan ve tüm kayıtlı değerleri yükleyen fonksiyon
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    // Eşikleri yükle
    warningThreshold =
        _prefs.getDouble(_warningThresholdKey) ?? _defaultWarningThreshold;
    errorThreshold =
        _prefs.getDouble(_errorThresholdKey) ?? _defaultErrorThreshold;

    // Renkleri yükle
    transmitterColors = [];
    for (int i = 0; i < 4; i++) {
      // Kayıtlı renk değerini (int) oku
      final int? savedColorValue = _prefs.getInt('$_colorKeyPrefix$i');
      if (savedColorValue != null) {
        // Kayıtlı değer varsa Color nesnesine çevir
        transmitterColors.add(Color(savedColorValue));
      } else {
        // Yoksa varsayılan rengi kullan
        transmitterColors.add(_defaultColors[i]);
      }
    }
  }

  // Eşikleri kaydetme fonksiyonları (Değişiklik yok)
  Future<void> setWarningThreshold(double value) async {
    warningThreshold = value;
    await _prefs.setDouble(_warningThresholdKey, value);
  }

  Future<void> setErrorThreshold(double value) async {
    errorThreshold = value;
    await _prefs.setDouble(_errorThresholdKey, value);
  }

  // --- YENİ ---
  // Belirli bir vericinin rengini kaydeder
  Future<void> setTransmitterColor(int index, Color color) async {
    if (index < 0 || index >= transmitterColors.length) return;

    transmitterColors[index] = color;
    // Color nesnesinin 'value' (int) değerini kaydet
    await _prefs.setInt('$_colorKeyPrefix$index', color.value);
  }
}
