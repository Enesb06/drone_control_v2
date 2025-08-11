// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get productCodePageTitle => 'Product Code Entry';

  @override
  String get welcomeMessage => 'Welcome to the Drone Test Application';

  @override
  String get productCodePrompt => 'Please enter the product ID or scan the QR code.';

  @override
  String get productIDFieldLabel => 'Product ID';

  @override
  String get scanQRCodeTooltip => 'Scan QR Code';

  @override
  String get startTestButton => 'Start Test';

  @override
  String get qrScannerPageTitle => 'Scan QR Code';

  @override
  String get homePageTitle => 'Control Panel';

  @override
  String get savedSessionsTooltip => 'Saved Sessions';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get statusChecking => 'Checking...';

  @override
  String get statusPleaseWait => 'Please wait.';

  @override
  String get statusConnectedToDevice => 'Connected to Device';

  @override
  String get statusDataStreamActive => 'Data stream is active.';

  @override
  String get statusWaitingForData => 'Waiting for data...';

  @override
  String get statusNotConnectedToDevice => 'Not Connected to Device';

  @override
  String get statusConnectToWifiPrompt => 'Please connect to the device\'s Wi-Fi network.';

  @override
  String get viewGraphButton => 'View Graph';

  @override
  String get connectToDeviceWifiButton => 'Connect to Device Wi-Fi';

  @override
  String dashboardAppBarTitleMotor(Object motorNumber) {
    return 'Motor $motorNumber';
  }

  @override
  String get dashboardAppBarTitleAllMotors => 'All Motors';

  @override
  String get dashboardAppBarTitleFFT => '(FFT)';

  @override
  String get stopRecordingTooltip => 'Stop and Save Recording';

  @override
  String get showTimeGraphTooltip => 'Show Time-Series Graph';

  @override
  String get showFFTGraphTooltip => 'Show FFT Graph';

  @override
  String get fftAnalysisNotAvailableForAll => 'FFT analysis is only available for single sensors.';

  @override
  String get fftAmplitude => 'Amplitude';

  @override
  String get fftFrequency => 'Frequency (Hz)';

  @override
  String get allButton => 'ALL';

  @override
  String get warningThresholdLabel => 'Warning';

  @override
  String get errorThresholdLabel => 'Error';

  @override
  String get dataRecordingStarted => 'Data recording started automatically.';

  @override
  String get saveSessionDialogTitle => 'Save Session';

  @override
  String get saveSessionDialogContent => 'Do you want to save this data recording as a file?';

  @override
  String get dontSaveButton => 'Don\'t Save';

  @override
  String get saveButton => 'Save';

  @override
  String get sessionNotSaved => 'Session not saved.';

  @override
  String sessionSavedSuccessfully(Object fileName) {
    return 'Session saved successfully: $fileName';
  }

  @override
  String errorSavingSession(Object error) {
    return 'Error: Could not save session. $error';
  }

  @override
  String get wifiSelectionPageTitle => 'Connect to Device Wi-Fi';

  @override
  String get refreshNetworksTooltip => 'Refresh Networks';

  @override
  String get connectingToNetwork => 'Connecting to network...';

  @override
  String get noWifiNetworksFound => 'No Wi-Fi networks found nearby.';

  @override
  String get rescanButton => 'Scan Again';

  @override
  String onlyConnectToTargetSsid(Object ssid) {
    return 'You can only connect to the \'$ssid\' network.';
  }

  @override
  String connectionError(Object error) {
    return 'Connection error: $error';
  }

  @override
  String get connectButton => 'Connect';

  @override
  String signalStrength(Object level) {
    return 'Signal: $level dBm';
  }

  @override
  String get savedSessionsPageTitle => 'Saved Sessions';

  @override
  String get refreshButton => 'Refresh';

  @override
  String get noSavedSessions => 'No saved sessions yet.';

  @override
  String get deleteSessionDialogTitle => 'Delete Session';

  @override
  String get deleteSessionDialogContent => 'Are you sure you want to permanently delete this session?';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get deleteButton => 'Delete';

  @override
  String get sessionDeletedSuccessfully => 'Session deleted successfully.';

  @override
  String productIdLabel(Object code) {
    return 'Product ID: $code';
  }

  @override
  String dateLabel(Object date) {
    return 'Date: $date';
  }

  @override
  String viewSessionPageTitle(Object motorNumber) {
    return 'Saved Session: Motor $motorNumber';
  }

  @override
  String get resetViewTooltip => 'Reset View';

  @override
  String noDataForMotor(Object motorNumber) {
    return 'No recorded data found for Motor $motorNumber.';
  }

  @override
  String get settingsPageTitle => 'General Settings';

  @override
  String get vibrationThresholds => 'Vibration Thresholds';

  @override
  String get warningThresholdSetting => 'Warning Threshold (Yellow)';

  @override
  String get errorThresholdSetting => 'Error Threshold (Red)';

  @override
  String get graphColors => 'Graph Colors';

  @override
  String motorColorSetting(Object motorNumber) {
    return 'Motor $motorNumber Color';
  }

  @override
  String get saveAllSettingsButton => 'Save All Settings';

  @override
  String get fieldCannotBeEmpty => 'This field cannot be empty';

  @override
  String get warningThresholdMustBeLower => 'Warning threshold must be lower than the Error threshold!';

  @override
  String get settingsSavedSuccessfully => 'Settings saved successfully!';

  @override
  String selectMotorColorTitle(Object motorNumber) {
    return 'Select Motor $motorNumber Color';
  }

  @override
  String get okButton => 'OK';

  @override
  String get changeButton => 'Change';
}
