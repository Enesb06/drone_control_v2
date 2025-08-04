import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // Ayarları saklamak için kullanılacak anahtarlar (keys)
  static const String _warningThresholdKey = 'warning_threshold';
  static const String _errorThresholdKey = 'error_threshold';

  // Varsayılan değerler
  static const double _defaultWarningThreshold = 2.0;
  static const double _defaultErrorThreshold = 4.0;

  // Singleton (Tekil Örnek) yapısı - uygulama boyunca tek bir instance olmasını sağlar
  SettingsService._privateConstructor();
  static final SettingsService instance = SettingsService._privateConstructor();

  late SharedPreferences _prefs;

  // Değerleri tutacak değişkenler
  late double warningThreshold;
  late double errorThreshold;

  // Servisi başlatan ve kayıtlı değerleri yükleyen fonksiyon
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    warningThreshold =
        _prefs.getDouble(_warningThresholdKey) ?? _defaultWarningThreshold;
    errorThreshold =
        _prefs.getDouble(_errorThresholdKey) ?? _defaultErrorThreshold;
  }

  // Uyarı eşiğini kaydeder
  Future<void> setWarningThreshold(double value) async {
    warningThreshold = value;
    await _prefs.setDouble(_warningThresholdKey, value);
  }

  // Hata (sınır dışı) eşiğini kaydeder
  Future<void> setErrorThreshold(double value) async {
    errorThreshold = value;
    await _prefs.setDouble(_errorThresholdKey, value);
  }
}
