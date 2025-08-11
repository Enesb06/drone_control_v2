// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get productCodePageTitle => 'Ürün Kodu Girişi';

  @override
  String get welcomeMessage => 'Drone Test Uygulamasına Hoşgeldiniz';

  @override
  String get productCodePrompt => 'Lütfen ürün ID girin veya QR kodu taratın.';

  @override
  String get productIDFieldLabel => 'Ürün ID';

  @override
  String get scanQRCodeTooltip => 'QR Kodu Tara';

  @override
  String get startTestButton => 'Teste Başla';

  @override
  String get qrScannerPageTitle => 'QR Kodu Tara';

  @override
  String get homePageTitle => 'Kontrol Paneli';

  @override
  String get savedSessionsTooltip => 'Kayıtlı Oturumlar';

  @override
  String get settingsTooltip => 'Ayarlar';

  @override
  String get statusChecking => 'Kontrol Ediliyor...';

  @override
  String get statusPleaseWait => 'Lütfen bekleyin.';

  @override
  String get statusConnectedToDevice => 'Cihaza Bağlı';

  @override
  String get statusDataStreamActive => 'Veri akışı aktif.';

  @override
  String get statusWaitingForData => 'Veri bekleniyor...';

  @override
  String get statusNotConnectedToDevice => 'Cihaza Bağlı Değil';

  @override
  String get statusConnectToWifiPrompt => 'Lütfen cihazın Wi-Fi ağına bağlanın.';

  @override
  String get viewGraphButton => 'Grafiği Görüntüle';

  @override
  String get connectToDeviceWifiButton => 'Cihaz Wi-Fi Ağına Bağlan';

  @override
  String dashboardAppBarTitleMotor(Object motorNumber) {
    return 'Motor $motorNumber';
  }

  @override
  String get dashboardAppBarTitleAllMotors => 'Tüm Motorlar';

  @override
  String get dashboardAppBarTitleFFT => '(FFT)';

  @override
  String get stopRecordingTooltip => 'Kaydı Durdur ve Sakla';

  @override
  String get showTimeGraphTooltip => 'Zaman Grafiğini Göster';

  @override
  String get showFFTGraphTooltip => 'FFT Grafiğini Göster';

  @override
  String get fftAnalysisNotAvailableForAll => 'FFT analizi sadece tekil sensörler için geçerlidir.';

  @override
  String get fftAmplitude => 'Genlik';

  @override
  String get fftFrequency => 'Frekans (Hz)';

  @override
  String get allButton => 'TÜM';

  @override
  String get warningThresholdLabel => 'Uyarı';

  @override
  String get errorThresholdLabel => 'Hata';

  @override
  String get dataRecordingStarted => 'Veri kaydı otomatik olarak başladı.';

  @override
  String get saveSessionDialogTitle => 'Oturumu Kaydet';

  @override
  String get saveSessionDialogContent => 'Bu veri kaydını bir dosya olarak saklamak istiyor musunuz?';

  @override
  String get dontSaveButton => 'Kaydetme';

  @override
  String get saveButton => 'Kaydet';

  @override
  String get sessionNotSaved => 'Oturum kaydedilmedi.';

  @override
  String sessionSavedSuccessfully(Object fileName) {
    return 'Oturum başarıyla kaydedildi: $fileName';
  }

  @override
  String errorSavingSession(Object error) {
    return 'Hata: Oturum kaydedilemedi. $error';
  }

  @override
  String get wifiSelectionPageTitle => 'Cihaz Wi-Fi Ağına Bağlan';

  @override
  String get refreshNetworksTooltip => 'Ağları Yenile';

  @override
  String get connectingToNetwork => 'Ağa bağlanılıyor...';

  @override
  String get noWifiNetworksFound => 'Yakında Wi-Fi ağı bulunamadı.';

  @override
  String get rescanButton => 'Tekrar Tara';

  @override
  String onlyConnectToTargetSsid(Object ssid) {
    return 'Sadece \'$ssid\' ağına bağlanabilirsiniz.';
  }

  @override
  String connectionError(Object error) {
    return 'Bağlanma hatası: $error';
  }

  @override
  String get connectButton => 'Bağlan';

  @override
  String signalStrength(Object level) {
    return 'Sinyal: $level dBm';
  }

  @override
  String get savedSessionsPageTitle => 'Kayıtlı Oturumlar';

  @override
  String get refreshButton => 'Yenile';

  @override
  String get noSavedSessions => 'Henüz kaydedilmiş bir oturum yok.';

  @override
  String get deleteSessionDialogTitle => 'Oturumu Sil';

  @override
  String get deleteSessionDialogContent => 'Bu oturumu kalıcı olarak silmek istediğinizden emin misiniz?';

  @override
  String get cancelButton => 'İptal';

  @override
  String get deleteButton => 'Sil';

  @override
  String get sessionDeletedSuccessfully => 'Oturum başarıyla silindi.';

  @override
  String productIdLabel(Object code) {
    return 'Ürün ID: $code';
  }

  @override
  String dateLabel(Object date) {
    return 'Tarih: $date';
  }

  @override
  String viewSessionPageTitle(Object motorNumber) {
    return 'Kayıtlı Oturum: Motor $motorNumber';
  }

  @override
  String get resetViewTooltip => 'Görünümü Sıfırla';

  @override
  String noDataForMotor(Object motorNumber) {
    return 'Motor $motorNumber için kayıtlı veri bulunamadı.';
  }

  @override
  String get settingsPageTitle => 'Genel Ayarlar';

  @override
  String get vibrationThresholds => 'Titreşim Eşikleri';

  @override
  String get warningThresholdSetting => 'Uyarı Eşiği (Sarı)';

  @override
  String get errorThresholdSetting => 'Hata Eşiği (Kırmızı)';

  @override
  String get graphColors => 'Grafik Renkleri';

  @override
  String motorColorSetting(Object motorNumber) {
    return 'Motor $motorNumber Rengi';
  }

  @override
  String get saveAllSettingsButton => 'Tüm Ayarları Kaydet';

  @override
  String get fieldCannotBeEmpty => 'Bu alan boş bırakılamaz';

  @override
  String get warningThresholdMustBeLower => 'Uyarı eşiği, Hata eşiğinden küçük olmalıdır!';

  @override
  String get settingsSavedSuccessfully => 'Ayarlar başarıyla kaydedildi!';

  @override
  String selectMotorColorTitle(Object motorNumber) {
    return 'Motor $motorNumber Rengini Seçin';
  }

  @override
  String get okButton => 'Tamam';

  @override
  String get changeButton => 'Değiştir';
}
