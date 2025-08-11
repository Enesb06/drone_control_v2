import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @productCodePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Code Entry'**
  String get productCodePageTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the Drone Test Application'**
  String get welcomeMessage;

  /// No description provided for @productCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter the product ID or scan the QR code.'**
  String get productCodePrompt;

  /// No description provided for @productIDFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Product ID'**
  String get productIDFieldLabel;

  /// No description provided for @scanQRCodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQRCodeTooltip;

  /// No description provided for @startTestButton.
  ///
  /// In en, this message translates to:
  /// **'Start Test'**
  String get startTestButton;

  /// No description provided for @qrScannerPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get qrScannerPageTitle;

  /// No description provided for @homePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Control Panel'**
  String get homePageTitle;

  /// No description provided for @savedSessionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Saved Sessions'**
  String get savedSessionsTooltip;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @statusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get statusChecking;

  /// No description provided for @statusPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait.'**
  String get statusPleaseWait;

  /// No description provided for @statusConnectedToDevice.
  ///
  /// In en, this message translates to:
  /// **'Connected to Device'**
  String get statusConnectedToDevice;

  /// No description provided for @statusDataStreamActive.
  ///
  /// In en, this message translates to:
  /// **'Data stream is active.'**
  String get statusDataStreamActive;

  /// No description provided for @statusWaitingForData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for data...'**
  String get statusWaitingForData;

  /// No description provided for @statusNotConnectedToDevice.
  ///
  /// In en, this message translates to:
  /// **'Not Connected to Device'**
  String get statusNotConnectedToDevice;

  /// No description provided for @statusConnectToWifiPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please connect to the device\'s Wi-Fi network.'**
  String get statusConnectToWifiPrompt;

  /// No description provided for @viewGraphButton.
  ///
  /// In en, this message translates to:
  /// **'View Graph'**
  String get viewGraphButton;

  /// No description provided for @connectToDeviceWifiButton.
  ///
  /// In en, this message translates to:
  /// **'Connect to Device Wi-Fi'**
  String get connectToDeviceWifiButton;

  /// No description provided for @dashboardAppBarTitleMotor.
  ///
  /// In en, this message translates to:
  /// **'Motor {motorNumber}'**
  String dashboardAppBarTitleMotor(Object motorNumber);

  /// No description provided for @dashboardAppBarTitleAllMotors.
  ///
  /// In en, this message translates to:
  /// **'All Motors'**
  String get dashboardAppBarTitleAllMotors;

  /// No description provided for @dashboardAppBarTitleFFT.
  ///
  /// In en, this message translates to:
  /// **'(FFT)'**
  String get dashboardAppBarTitleFFT;

  /// No description provided for @stopRecordingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop and Save Recording'**
  String get stopRecordingTooltip;

  /// No description provided for @showTimeGraphTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show Time-Series Graph'**
  String get showTimeGraphTooltip;

  /// No description provided for @showFFTGraphTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show FFT Graph'**
  String get showFFTGraphTooltip;

  /// No description provided for @fftAnalysisNotAvailableForAll.
  ///
  /// In en, this message translates to:
  /// **'FFT analysis is only available for single sensors.'**
  String get fftAnalysisNotAvailableForAll;

  /// No description provided for @fftAmplitude.
  ///
  /// In en, this message translates to:
  /// **'Amplitude'**
  String get fftAmplitude;

  /// No description provided for @fftFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency (Hz)'**
  String get fftFrequency;

  /// No description provided for @allButton.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get allButton;

  /// No description provided for @warningThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warningThresholdLabel;

  /// No description provided for @errorThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorThresholdLabel;

  /// No description provided for @dataRecordingStarted.
  ///
  /// In en, this message translates to:
  /// **'Data recording started automatically.'**
  String get dataRecordingStarted;

  /// No description provided for @saveSessionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Session'**
  String get saveSessionDialogTitle;

  /// No description provided for @saveSessionDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save this data recording as a file?'**
  String get saveSessionDialogContent;

  /// No description provided for @dontSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Don\'t Save'**
  String get dontSaveButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @sessionNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Session not saved.'**
  String get sessionNotSaved;

  /// No description provided for @sessionSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Session saved successfully: {fileName}'**
  String sessionSavedSuccessfully(Object fileName);

  /// No description provided for @errorSavingSession.
  ///
  /// In en, this message translates to:
  /// **'Error: Could not save session. {error}'**
  String errorSavingSession(Object error);

  /// No description provided for @wifiSelectionPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to Device Wi-Fi'**
  String get wifiSelectionPageTitle;

  /// No description provided for @refreshNetworksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh Networks'**
  String get refreshNetworksTooltip;

  /// No description provided for @connectingToNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connecting to network...'**
  String get connectingToNetwork;

  /// No description provided for @noWifiNetworksFound.
  ///
  /// In en, this message translates to:
  /// **'No Wi-Fi networks found nearby.'**
  String get noWifiNetworksFound;

  /// No description provided for @rescanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan Again'**
  String get rescanButton;

  /// No description provided for @onlyConnectToTargetSsid.
  ///
  /// In en, this message translates to:
  /// **'You can only connect to the \'{ssid}\' network.'**
  String onlyConnectToTargetSsid(Object ssid);

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error: {error}'**
  String connectionError(Object error);

  /// No description provided for @connectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectButton;

  /// No description provided for @signalStrength.
  ///
  /// In en, this message translates to:
  /// **'Signal: {level} dBm'**
  String signalStrength(Object level);

  /// No description provided for @savedSessionsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Sessions'**
  String get savedSessionsPageTitle;

  /// No description provided for @refreshButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshButton;

  /// No description provided for @noSavedSessions.
  ///
  /// In en, this message translates to:
  /// **'No saved sessions yet.'**
  String get noSavedSessions;

  /// No description provided for @deleteSessionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get deleteSessionDialogTitle;

  /// No description provided for @deleteSessionDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete this session?'**
  String get deleteSessionDialogContent;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @sessionDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Session deleted successfully.'**
  String get sessionDeletedSuccessfully;

  /// No description provided for @productIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Product ID: {code}'**
  String productIdLabel(Object code);

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dateLabel(Object date);

  /// No description provided for @viewSessionPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Session: Motor {motorNumber}'**
  String viewSessionPageTitle(Object motorNumber);

  /// No description provided for @resetViewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset View'**
  String get resetViewTooltip;

  /// No description provided for @noDataForMotor.
  ///
  /// In en, this message translates to:
  /// **'No recorded data found for Motor {motorNumber}.'**
  String noDataForMotor(Object motorNumber);

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get settingsPageTitle;

  /// No description provided for @vibrationThresholds.
  ///
  /// In en, this message translates to:
  /// **'Vibration Thresholds'**
  String get vibrationThresholds;

  /// No description provided for @warningThresholdSetting.
  ///
  /// In en, this message translates to:
  /// **'Warning Threshold (Yellow)'**
  String get warningThresholdSetting;

  /// No description provided for @errorThresholdSetting.
  ///
  /// In en, this message translates to:
  /// **'Error Threshold (Red)'**
  String get errorThresholdSetting;

  /// No description provided for @graphColors.
  ///
  /// In en, this message translates to:
  /// **'Graph Colors'**
  String get graphColors;

  /// No description provided for @motorColorSetting.
  ///
  /// In en, this message translates to:
  /// **'Motor {motorNumber} Color'**
  String motorColorSetting(Object motorNumber);

  /// No description provided for @saveAllSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Save All Settings'**
  String get saveAllSettingsButton;

  /// No description provided for @fieldCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'This field cannot be empty'**
  String get fieldCannotBeEmpty;

  /// No description provided for @warningThresholdMustBeLower.
  ///
  /// In en, this message translates to:
  /// **'Warning threshold must be lower than the Error threshold!'**
  String get warningThresholdMustBeLower;

  /// No description provided for @settingsSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully!'**
  String get settingsSavedSuccessfully;

  /// No description provided for @selectMotorColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Motor {motorNumber} Color'**
  String selectMotorColorTitle(Object motorNumber);

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @changeButton.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeButton;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'tr': return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
