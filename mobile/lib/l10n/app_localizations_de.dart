// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Vapen';

  @override
  String get loginTitle => 'Anmelden';

  @override
  String get registerTitle => 'Registrieren';

  @override
  String get emailLabel => 'E-Mail';

  @override
  String get passwordLabel => 'Passwort';

  @override
  String get displayNameLabel => 'Anzeigename';

  @override
  String get serverUrlLabel => 'Server-URL';

  @override
  String get serverSetupTitle => 'Server verbinden';

  @override
  String get serverSetupDescription =>
      'Gib die Adresse deiner Vapen-Instanz ein (Origin, ohne /api/v1). Die Verbindung wird getestet, bevor du dich anmelden kannst.';

  @override
  String get serverConnectionTestButton => 'Verbindung testen';

  @override
  String get serverConnectionFailed =>
      'Verbindung zum Server fehlgeschlagen. Prüfe die URL und ob der Server erreichbar ist.';

  @override
  String serverConfiguredHint(String url) {
    return 'Server: $url';
  }

  @override
  String get changeServerButton => 'Server ändern';

  @override
  String get loginButton => 'Anmelden';

  @override
  String get registerButton => 'Konto erstellen';

  @override
  String get logoutButton => 'Abmelden';

  @override
  String get homeTitle => 'Übersicht';

  @override
  String get statsTitle => 'Statistik';

  @override
  String get groupsTitle => 'Gruppen';

  @override
  String get privacyTitle => 'Privatsphäre';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get trackingEnabled => 'Tracking aktiv';

  @override
  String get trackingDisabled => 'Tracking pausiert';

  @override
  String get connectionLive => 'Verbunden';

  @override
  String get connectionWaiting => 'Warte auf Gerät';

  @override
  String get connectionDisconnected => 'Getrennt';

  @override
  String pendingUploads(int count) {
    return '$count ausstehende Uploads';
  }

  @override
  String todayPuffs(int count) {
    return 'Heute: $count Züge';
  }

  @override
  String get permissionsTitle => 'Berechtigungen';

  @override
  String get permissionsBluetooth =>
      'Bluetooth wird benötigt, um deine Elfbar Master auszulesen.';

  @override
  String get permissionsNotifications =>
      'Benachrichtigungen zeigen den Tracking-Status im Hintergrund.';

  @override
  String get permissionsBattery =>
      'Ohne Batterie-Optimierung kann Android das Tracking beenden.';

  @override
  String get continueButton => 'Weiter';

  @override
  String get pairDeviceTitle => 'Gerät koppeln';

  @override
  String get pairDeviceHint =>
      'Wähle deine Elfbar Master in der Systemliste. Schließe InnoGate, falls es läuft.';

  @override
  String get bleExplorerTitle => 'BLE Explorer';

  @override
  String get developerMode => 'Entwicklermodus';

  @override
  String get simulatedDevice => 'Simuliertes Gerät';

  @override
  String get invalidCredentials => 'E-Mail oder Passwort ist falsch.';

  @override
  String get invalidServerUrl => 'Ungültige Server-URL';

  @override
  String get genericError =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get serverEndpointTitle => 'Server';

  @override
  String get serverEndpointDescription =>
      'Adresse deiner Vapen-Instanz (Origin, ohne /api/v1). Öffentliche Server sollten HTTPS nutzen; HTTP ist für localhost und private Netzwerke erlaubt.';

  @override
  String get serverEndpointSave => 'Speichern';

  @override
  String get serverEndpointSaved => 'Server-URL gespeichert';

  @override
  String get serverEndpointChangeLogout =>
      'Bei einer anderen URL wirst du abgemeldet. Hintergrund-Uploads stoppen, bis du dich erneut anmeldest und das Gerät ggf. neu koppelst.';

  @override
  String get cancelButton => 'Abbrechen';
}
