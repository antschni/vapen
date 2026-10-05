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
  String get serverConnectionSuccess => 'Verbindung erfolgreich.';

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
  String get statsNotSignedIn => 'Melde dich an, um Statistiken zu sehen.';

  @override
  String get groupsTitle => 'Gruppen';

  @override
  String get groupInviteCode => 'Einladungscode';

  @override
  String get groupInviteLink => 'Einladungslink';

  @override
  String get groupCopyCode => 'Code kopieren';

  @override
  String get groupCopyLink => 'Link kopieren';

  @override
  String get groupInviteCopied => 'In die Zwischenablage kopiert';

  @override
  String get groupLeaderboard => 'Rangliste';

  @override
  String get groupRangeToday => 'Heute';

  @override
  String get groupRange7d => '7 Tage';

  @override
  String get groupRange30d => '30 Tage';

  @override
  String groupLeaderboardPuffs(String count) {
    return '$count Züge';
  }

  @override
  String get groupMembersTitle => 'Mitglieder';

  @override
  String get groupMembersManage => 'Mitglieder verwalten';

  @override
  String get groupRoleOwner => 'Inhaber';

  @override
  String get groupRoleAdmin => 'Admin';

  @override
  String get groupRoleMember => 'Mitglied';

  @override
  String get groupPromoteAdmin => 'Zum Admin machen';

  @override
  String get groupDemoteMember => 'Admin-Rechte entziehen';

  @override
  String get groupTransferOwnership => 'Inhaberschaft übertragen';

  @override
  String groupTransferOwnershipConfirm(String name) {
    return 'Inhaberschaft wirklich an $name übertragen? Du wirst danach Admin.';
  }

  @override
  String get groupRemoveMember => 'Entfernen';

  @override
  String groupRemoveMemberConfirm(String name) {
    return '$name wirklich aus der Gruppe entfernen?';
  }

  @override
  String get groupLeave => 'Gruppe verlassen';

  @override
  String get groupLeaveConfirm => 'Gruppe wirklich verlassen?';

  @override
  String get groupDelete => 'Gruppe löschen';

  @override
  String get groupDeleteConfirm =>
      'Gruppe unwiderruflich löschen? Alle Mitglieder verlieren den Zugang.';

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
  String get connectionConnecting => 'Verbinde…';

  @override
  String get connectionDiscovering => 'Dienste werden ermittelt…';

  @override
  String get connectionInitializing => 'Initialisiere…';

  @override
  String get connectionIdle => 'Inaktiv';

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
  String get pairDeviceButton => 'Suchen & koppeln';

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

  @override
  String get devicesTitle => 'Geräte';

  @override
  String get devicesEmpty => 'Noch kein Gerät registriert.';

  @override
  String get devicesEmptyHint => 'Kopple deine Elfbar, um Puffs zu tracken.';

  @override
  String get deviceLastSeen => 'Zuletzt gesehen';

  @override
  String get deviceNeverSeen => 'Noch nie';

  @override
  String get deviceDetailTitle => 'Gerät';

  @override
  String get deviceActiveOnPhone => 'Auf diesem Telefon aktiv';

  @override
  String get deviceSectionStatus => 'Status';

  @override
  String get deviceSectionInfo => 'Informationen';

  @override
  String get deviceBattery => 'Akku';

  @override
  String get deviceLiquid => 'Liquid';

  @override
  String get deviceCharging => 'Laden';

  @override
  String get deviceChargingYes => 'Ja';

  @override
  String get deviceChargingNo => 'Nein';

  @override
  String get deviceFirmware => 'Firmware (Status)';

  @override
  String get deviceFirmwareReported => 'Firmware (Gerät)';

  @override
  String get deviceStatusRecorded => 'Status erfasst';

  @override
  String get deviceNoStatusYet => 'Noch kein Status vom Gerät empfangen.';

  @override
  String get deviceRegistered => 'Registriert';

  @override
  String get deviceHardwareId => 'Hardware-ID';

  @override
  String get deviceDeleteTitle => 'Gerät löschen';

  @override
  String get deviceDeleteAction => 'Gerät löschen';

  @override
  String get deviceDeleteConfirm =>
      'Gerät und alle zugehörigen Daten wirklich löschen?';
}
