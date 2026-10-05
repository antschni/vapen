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

  /// No description provided for @serverSetupTitle.
  ///
  /// In de, this message translates to:
  /// **'Server verbinden'**
  String get serverSetupTitle;

  /// No description provided for @serverSetupDescription.
  ///
  /// In de, this message translates to:
  /// **'Gib die Adresse deiner Vapen-Instanz ein (Origin, ohne /api/v1). Die Verbindung wird getestet, bevor du dich anmelden kannst.'**
  String get serverSetupDescription;

  /// No description provided for @serverConnectionTestButton.
  ///
  /// In de, this message translates to:
  /// **'Verbindung testen'**
  String get serverConnectionTestButton;

  /// No description provided for @serverConnectionFailed.
  ///
  /// In de, this message translates to:
  /// **'Verbindung zum Server fehlgeschlagen. Prüfe die URL und ob der Server erreichbar ist.'**
  String get serverConnectionFailed;

  /// No description provided for @serverConnectionSuccess.
  ///
  /// In de, this message translates to:
  /// **'Verbindung erfolgreich.'**
  String get serverConnectionSuccess;

  /// No description provided for @serverConfiguredHint.
  ///
  /// In de, this message translates to:
  /// **'Server: {url}'**
  String serverConfiguredHint(String url);

  /// No description provided for @changeServerButton.
  ///
  /// In de, this message translates to:
  /// **'Server ändern'**
  String get changeServerButton;

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

  /// No description provided for @statsNotSignedIn.
  ///
  /// In de, this message translates to:
  /// **'Melde dich an, um Statistiken zu sehen.'**
  String get statsNotSignedIn;

  /// No description provided for @groupsTitle.
  ///
  /// In de, this message translates to:
  /// **'Gruppen'**
  String get groupsTitle;

  /// No description provided for @groupInviteCode.
  ///
  /// In de, this message translates to:
  /// **'Einladungscode'**
  String get groupInviteCode;

  /// No description provided for @groupInviteLink.
  ///
  /// In de, this message translates to:
  /// **'Einladungslink'**
  String get groupInviteLink;

  /// No description provided for @groupCopyCode.
  ///
  /// In de, this message translates to:
  /// **'Code kopieren'**
  String get groupCopyCode;

  /// No description provided for @groupCopyLink.
  ///
  /// In de, this message translates to:
  /// **'Link kopieren'**
  String get groupCopyLink;

  /// No description provided for @groupInviteCopied.
  ///
  /// In de, this message translates to:
  /// **'In die Zwischenablage kopiert'**
  String get groupInviteCopied;

  /// No description provided for @groupLeaderboard.
  ///
  /// In de, this message translates to:
  /// **'Rangliste'**
  String get groupLeaderboard;

  /// No description provided for @groupRangeToday.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get groupRangeToday;

  /// No description provided for @groupRange7d.
  ///
  /// In de, this message translates to:
  /// **'7 Tage'**
  String get groupRange7d;

  /// No description provided for @groupRange30d.
  ///
  /// In de, this message translates to:
  /// **'30 Tage'**
  String get groupRange30d;

  /// No description provided for @groupLeaderboardPuffs.
  ///
  /// In de, this message translates to:
  /// **'{count} Züge'**
  String groupLeaderboardPuffs(String count);

  /// No description provided for @groupMembersTitle.
  ///
  /// In de, this message translates to:
  /// **'Mitglieder'**
  String get groupMembersTitle;

  /// No description provided for @groupMembersManage.
  ///
  /// In de, this message translates to:
  /// **'Mitglieder verwalten'**
  String get groupMembersManage;

  /// No description provided for @groupRoleOwner.
  ///
  /// In de, this message translates to:
  /// **'Inhaber'**
  String get groupRoleOwner;

  /// No description provided for @groupRoleAdmin.
  ///
  /// In de, this message translates to:
  /// **'Admin'**
  String get groupRoleAdmin;

  /// No description provided for @groupRoleMember.
  ///
  /// In de, this message translates to:
  /// **'Mitglied'**
  String get groupRoleMember;

  /// No description provided for @groupPromoteAdmin.
  ///
  /// In de, this message translates to:
  /// **'Zum Admin machen'**
  String get groupPromoteAdmin;

  /// No description provided for @groupDemoteMember.
  ///
  /// In de, this message translates to:
  /// **'Admin-Rechte entziehen'**
  String get groupDemoteMember;

  /// No description provided for @groupTransferOwnership.
  ///
  /// In de, this message translates to:
  /// **'Inhaberschaft übertragen'**
  String get groupTransferOwnership;

  /// No description provided for @groupTransferOwnershipConfirm.
  ///
  /// In de, this message translates to:
  /// **'Inhaberschaft wirklich an {name} übertragen? Du wirst danach Admin.'**
  String groupTransferOwnershipConfirm(String name);

  /// No description provided for @groupRemoveMember.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get groupRemoveMember;

  /// No description provided for @groupRemoveMemberConfirm.
  ///
  /// In de, this message translates to:
  /// **'{name} wirklich aus der Gruppe entfernen?'**
  String groupRemoveMemberConfirm(String name);

  /// No description provided for @groupLeave.
  ///
  /// In de, this message translates to:
  /// **'Gruppe verlassen'**
  String get groupLeave;

  /// No description provided for @groupLeaveConfirm.
  ///
  /// In de, this message translates to:
  /// **'Gruppe wirklich verlassen?'**
  String get groupLeaveConfirm;

  /// No description provided for @groupDelete.
  ///
  /// In de, this message translates to:
  /// **'Gruppe löschen'**
  String get groupDelete;

  /// No description provided for @groupDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Gruppe unwiderruflich löschen? Alle Mitglieder verlieren den Zugang.'**
  String get groupDeleteConfirm;

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

  /// No description provided for @connectionConnecting.
  ///
  /// In de, this message translates to:
  /// **'Verbinde…'**
  String get connectionConnecting;

  /// No description provided for @connectionDiscovering.
  ///
  /// In de, this message translates to:
  /// **'Dienste werden ermittelt…'**
  String get connectionDiscovering;

  /// No description provided for @connectionInitializing.
  ///
  /// In de, this message translates to:
  /// **'Initialisiere…'**
  String get connectionInitializing;

  /// No description provided for @connectionIdle.
  ///
  /// In de, this message translates to:
  /// **'Inaktiv'**
  String get connectionIdle;

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

  /// No description provided for @pairDeviceButton.
  ///
  /// In de, this message translates to:
  /// **'Suchen & koppeln'**
  String get pairDeviceButton;

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

  /// No description provided for @invalidServerUrl.
  ///
  /// In de, this message translates to:
  /// **'Ungültige Server-URL'**
  String get invalidServerUrl;

  /// No description provided for @genericError.
  ///
  /// In de, this message translates to:
  /// **'Etwas ist schiefgelaufen. Bitte versuche es erneut.'**
  String get genericError;

  /// No description provided for @serverEndpointTitle.
  ///
  /// In de, this message translates to:
  /// **'Server'**
  String get serverEndpointTitle;

  /// No description provided for @serverEndpointDescription.
  ///
  /// In de, this message translates to:
  /// **'Adresse deiner Vapen-Instanz (Origin, ohne /api/v1). Öffentliche Server sollten HTTPS nutzen; HTTP ist für localhost und private Netzwerke erlaubt.'**
  String get serverEndpointDescription;

  /// No description provided for @serverEndpointSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get serverEndpointSave;

  /// No description provided for @serverEndpointSaved.
  ///
  /// In de, this message translates to:
  /// **'Server-URL gespeichert'**
  String get serverEndpointSaved;

  /// No description provided for @serverEndpointChangeLogout.
  ///
  /// In de, this message translates to:
  /// **'Bei einer anderen URL wirst du abgemeldet. Hintergrund-Uploads stoppen, bis du dich erneut anmeldest und das Gerät ggf. neu koppelst.'**
  String get serverEndpointChangeLogout;

  /// No description provided for @cancelButton.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancelButton;

  /// No description provided for @devicesTitle.
  ///
  /// In de, this message translates to:
  /// **'Geräte'**
  String get devicesTitle;

  /// No description provided for @devicesEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Gerät registriert.'**
  String get devicesEmpty;

  /// No description provided for @devicesEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Kopple deine Elfbar, um Puffs zu tracken.'**
  String get devicesEmptyHint;

  /// No description provided for @deviceLastSeen.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gesehen'**
  String get deviceLastSeen;

  /// No description provided for @deviceNeverSeen.
  ///
  /// In de, this message translates to:
  /// **'Noch nie'**
  String get deviceNeverSeen;

  /// No description provided for @deviceDetailTitle.
  ///
  /// In de, this message translates to:
  /// **'Gerät'**
  String get deviceDetailTitle;

  /// No description provided for @deviceActiveOnPhone.
  ///
  /// In de, this message translates to:
  /// **'Auf diesem Telefon aktiv'**
  String get deviceActiveOnPhone;

  /// No description provided for @deviceSectionStatus.
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get deviceSectionStatus;

  /// No description provided for @deviceSectionInfo.
  ///
  /// In de, this message translates to:
  /// **'Informationen'**
  String get deviceSectionInfo;

  /// No description provided for @deviceBattery.
  ///
  /// In de, this message translates to:
  /// **'Akku'**
  String get deviceBattery;

  /// No description provided for @deviceLiquid.
  ///
  /// In de, this message translates to:
  /// **'Liquid'**
  String get deviceLiquid;

  /// No description provided for @deviceCharging.
  ///
  /// In de, this message translates to:
  /// **'Laden'**
  String get deviceCharging;

  /// No description provided for @deviceChargingYes.
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get deviceChargingYes;

  /// No description provided for @deviceChargingNo.
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get deviceChargingNo;

  /// No description provided for @deviceFirmware.
  ///
  /// In de, this message translates to:
  /// **'Firmware (Status)'**
  String get deviceFirmware;

  /// No description provided for @deviceFirmwareReported.
  ///
  /// In de, this message translates to:
  /// **'Firmware (Gerät)'**
  String get deviceFirmwareReported;

  /// No description provided for @deviceStatusRecorded.
  ///
  /// In de, this message translates to:
  /// **'Status erfasst'**
  String get deviceStatusRecorded;

  /// No description provided for @deviceNoStatusYet.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Status vom Gerät empfangen.'**
  String get deviceNoStatusYet;

  /// No description provided for @deviceRegistered.
  ///
  /// In de, this message translates to:
  /// **'Registriert'**
  String get deviceRegistered;

  /// No description provided for @deviceHardwareId.
  ///
  /// In de, this message translates to:
  /// **'Hardware-ID'**
  String get deviceHardwareId;

  /// No description provided for @deviceDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Gerät löschen'**
  String get deviceDeleteTitle;

  /// No description provided for @deviceDeleteAction.
  ///
  /// In de, this message translates to:
  /// **'Gerät löschen'**
  String get deviceDeleteAction;

  /// No description provided for @deviceDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Gerät und alle zugehörigen Daten wirklich löschen?'**
  String get deviceDeleteConfirm;
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
