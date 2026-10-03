import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'vapen',
    dartOut: 'lib/data/native/vapen_native.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/dev/vapen/app/bridge/VapenNativePigeon.kt',
    kotlinOptions: KotlinOptions(package: 'dev.vapen.app.bridge'),
  ),
)
class NativeCredentials {
  NativeCredentials({
    required this.baseUrl,
    required this.deviceId,
    required this.deviceToken,
    required this.hardwareId,
  });

  String baseUrl;
  String deviceId;
  String deviceToken;
  String hardwareId;
}

enum TrackingConnectionState { idle, waiting, connecting, discovering, initializing, live, disconnected }

class TrackingState {
  TrackingState({
    required this.enabled,
    required this.connectionState,
    this.batteryPercent,
    this.liquidPercent,
    this.isCharging,
    this.todayPuffCount,
    this.pendingUploads,
    this.lastError,
    this.simulationEnabled,
  });

  bool enabled;
  TrackingConnectionState connectionState;
  int? batteryPercent;
  int? liquidPercent;
  bool? isCharging;
  int? todayPuffCount;
  int? pendingUploads;
  String? lastError;
  bool? simulationEnabled;
}

class PuffInfo {
  PuffInfo({
    required this.startedAtEpochMs,
    required this.durationMs,
  });

  int startedAtEpochMs;
  int durationMs;
}

class StatusInfo {
  StatusInfo({
    this.batteryPercent,
    this.liquidPercent,
    this.isCharging,
    required this.recordedAtEpochMs,
  });

  int? batteryPercent;
  int? liquidPercent;
  bool? isCharging;
  int recordedAtEpochMs;
}

class PairingResult {
  PairingResult({required this.success, this.address, this.errorMessage});

  bool success;
  String? address;
  String? errorMessage;
}

class ExplorerScanFilter {
  ExplorerScanFilter({this.nameContains, this.minRssi});

  String? nameContains;
  int? minRssi;
}

enum ExplorerDirection { read, write, notify, indicate, scan, connect, disconnect, marker }

class ExplorerEvent {
  ExplorerEvent({
    required this.epochMs,
    required this.direction,
    this.serviceUuid,
    this.charUuid,
    required this.hex,
    this.note,
  });

  int epochMs;
  ExplorerDirection direction;
  String? serviceUuid;
  String? charUuid;
  String hex;
  String? note;
}

@HostApi()
abstract class TrackingHostApi {
  void setCredentials(NativeCredentials credentials);
  void clearCredentials();
  @async
  PairingResult associateDevice();
  void startTracking();
  void stopTracking();
  TrackingState getTrackingState();
  int getPendingEventCount();
  bool isIgnoringBatteryOptimizations();
  void requestIgnoreBatteryOptimizations();
  void setSimulationEnabled(bool enabled);
  void explorerStartScan(ExplorerScanFilter filter);
  void explorerStopScan();
  void explorerConnect(String address);
  void explorerDisconnect();
  void explorerWrite(String serviceUuid, String charUuid, String hex, bool withResponse);
  void explorerAddMarker(String note);
  String explorerExportLog();
}

@FlutterApi()
abstract class TrackingFlutterApi {
  void onTrackingStateChanged(TrackingState state);
  void onPuff(PuffInfo puff);
  void onStatus(StatusInfo status);
  void onExplorerEvent(ExplorerEvent event);
}
