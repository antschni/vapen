import Flutter
import UIKit

/// Registers the Pigeon tracking bridge with a Flutter engine.
final class VapenNativePlugin: NSObject, FlutterPlugin {
  private let hostApi: TrackingHostApiImpl

  private init(hostApi: TrackingHostApiImpl) {
    self.hostApi = hostApi
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let impl = TrackingHostApiImpl(flutterApi: TrackingFlutterApi(binaryMessenger: messenger))
    TrackingHostApiSetup.setUp(binaryMessenger: messenger, api: impl)
    registrar.publish(VapenNativePlugin(hostApi: impl))
    impl.attachEngine()
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    TrackingHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    hostApi.detachEngine()
  }
}

/// iOS implementation of the Pigeon `TrackingHostApi`; Pigeon calls it on the main thread.
final class TrackingHostApiImpl: TrackingHostApi {
  private let flutterApi: TrackingFlutterApi
  private let explorer: BleExplorerManager
  private var picker: DevicePicker?

  init(flutterApi: TrackingFlutterApi) {
    self.flutterApi = flutterApi
    explorer = BleExplorerManager(flutterApi: flutterApi)
  }

  func attachEngine() {
    TrackingController.shared.setFlutterApi(flutterApi)
    TrackingController.shared.resumeBleIfConfigured()
  }

  func detachEngine() {
    TrackingController.shared.setFlutterApi(nil)
  }

  func setCredentials(credentials: NativeCredentials) throws {
    TrackingController.shared.setNativeCredentials(credentials)
  }

  func clearCredentials() throws {
    TrackingController.shared.clearCredentials()
  }

  func getActiveDeviceId() throws -> String? {
    TrackingController.shared.activeDeviceId()
  }

  /// Native device picker instead of Android's Companion Device Manager. The returned address is
  /// the CoreBluetooth peripheral identifier.
  func associateDevice(completion: @escaping (Result<PairingResult, Error>) -> Void) {
    let picker = DevicePicker { UIApplication.shared.vapenTopViewController }
    self.picker = picker
    picker.pick { [weak self] outcome in
      self?.picker = nil
      switch outcome {
      case let .picked(address):
        TrackingController.shared.setPairedAddress(address)
        completion(.success(PairingResult(success: true, address: address, errorMessage: nil)))
      case let .failed(message):
        completion(.success(PairingResult(success: false, address: nil, errorMessage: message)))
      }
    }
  }

  func startTracking() throws {
    TrackingController.shared.startTracking()
  }

  func stopTracking() throws {
    TrackingController.shared.stopTracking()
  }

  func getTrackingState() throws -> TrackingState {
    TrackingController.shared.getState()
  }

  func getPendingEventCount() throws -> Int64 {
    Int64(TrackingController.shared.pendingCount())
  }

  /// iOS has no per-app battery optimization switch; background BLE is governed by the
  /// `bluetooth-central` background mode instead.
  func isIgnoringBatteryOptimizations() throws -> Bool { true }

  func requestIgnoreBatteryOptimizations() throws {}

  func setSimulationEnabled(enabled: Bool) throws {
    TrackingController.shared.setSimulationEnabled(enabled)
  }

  func explorerStartScan(filter: ExplorerScanFilter) throws {
    explorer.startScan(filter)
  }

  func explorerStopScan() throws {
    explorer.stopScan()
  }

  func explorerConnect(address: String) throws {
    explorer.connect(address)
  }

  func explorerDisconnect() throws {
    explorer.disconnect()
  }

  func explorerWrite(serviceUuid: String, charUuid: String, hex: String, withResponse: Bool) throws {
    explorer.write(serviceUuid: serviceUuid, charUuid: charUuid, hex: hex, withResponse: withResponse)
  }

  func explorerAddMarker(note: String) throws {
    explorer.addMarker(note)
  }

  func explorerExportLog() throws -> String {
    try explorer.exportLog()
  }
}
