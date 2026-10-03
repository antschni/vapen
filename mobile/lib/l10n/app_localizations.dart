import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('de')];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'Vapen'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get loginTitle;

  /// No description provided for @registerTitle.
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get registerTitle;

  /// No description provided for @emailLabel.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get passwordLabel;

  /// No description provided for @displayNameLabel.
  ///
  /// In de, this message translates to:
  /// **'Anzeigename'**
  String get displayNameLabel;

  /// No description provided for @serverUrlLabel.
  ///
  /// In de, this message translates to:
  /// **'Server-URL'**
  String get serverUrlLabel;

  /// No description provided for @loginButton.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In de, this message translates to:
  /// **'Konto erstellen'**
  String get registerButton;

  /// No description provided for @logoutButton.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get logoutButton;

  /// No description provided for @homeTitle.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get homeTitle;

  /// No description provided for @statsTitle.
  ///
  /// In de, this message translates to:
  /// **'Statistik'**
  String get statsTitle;

  /// No description provided for @groupsTitle.
  ///
  /// In de, this message translates to:
  /// **'Gruppen'**
  String get groupsTitle;

  /// No description provided for @privacyTitle.
  ///
  /// In de, this message translates to:
  /// **'Privatsphäre'**
  String get privacyTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settingsTitle;

  /// No description provided for @trackingEnabled.
  ///
  /// In de, this message translates to:
  /// **'Tracking aktiv'**
  String get trackingEnabled;

  /// No description provided for @trackingDisabled.
  ///
  /// In de, this message translates to:
  /// **'Tracking pausiert'**
  String get trackingDisabled;

  /// No description provided for @connectionLive.
  ///
  /// In de, this message translates to:
  /// **'Verbunden'**
  String get connectionLive;

  /// No description provided for @connectionWaiting.
  ///
  /// In de, this message translates to:
  /// **'Warte auf Gerät'**
  String get connectionWaiting;

  /// No description provided for @connectionDisconnected.
  ///
  /// In de, this message translates to:
  /// **'Getrennt'**
  String get connectionDisconnected;

  /// No description provided for @pendingUploads.
  ///
  /// In de, this message translates to:
  /// **'{count} ausstehende Uploads'**
  String pendingUploads(int count);

  /// No description provided for @todayPuffs.
  ///
  /// In de, this message translates to:
  /// **'Heute: {count} Züge'**
  String todayPuffs(int count);

  /// No description provided for @permissionsTitle.
  ///
  /// In de, this message translates to:
  /// **'Berechtigungen'**
  String get permissionsTitle;

  /// No description provided for @permissionsBluetooth.
  ///
  /// In de, this message translates to:
  /// **'Bluetooth wird benötigt, um deine Elfbar Master auszulesen.'**
  String get permissionsBluetooth;

  /// No description provided for @permissionsNotifications.
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen zeigen den Tracking-Status im Hintergrund.'**
  String get permissionsNotifications;

  /// No description provided for @permissionsBattery.
  ///
  /// In de, this message translates to:
  /// **'Ohne Batterie-Optimierung kann Android das Tracking beenden.'**
  String get permissionsBattery;

  /// No description provided for @continueButton.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get continueButton;

  /// No description provided for @pairDeviceTitle.
  ///
  /// In de, this message translates to:
  /// **'Gerät koppeln'**
  String get pairDeviceTitle;

  /// No description provided for @pairDeviceHint.
  ///
  /// In de, this message translates to:
  /// **'Wähle deine Elfbar Master in der Systemliste. Schließe InnoGate, falls es läuft.'**
  String get pairDeviceHint;

  /// No description provided for @bleExplorerTitle.
  ///
  /// In de, this message translates to:
  /// **'BLE Explorer'**
  String get bleExplorerTitle;

  /// No description provided for @developerMode.
  ///
  /// In de, this message translates to:
  /// **'Entwicklermodus'**
  String get developerMode;

  /// No description provided for @simulatedDevice.
  ///
  /// In de, this message translates to:
  /// **'Simuliertes Gerät'**
  String get simulatedDevice;

  /// No description provided for @invalidCredentials.
  ///
  /// In de, this message translates to:
  /// **'E-Mail oder Passwort ist falsch.'**
  String get invalidCredentials;

  /// No description provided for @genericError.
  ///
  /// In de, this message translates to:
  /// **'Etwas ist schiefgelaufen. Bitte versuche es erneut.'**
  String get genericError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
