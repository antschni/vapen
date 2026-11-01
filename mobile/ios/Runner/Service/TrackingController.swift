import CoreBluetooth
import UIKit

/// Owns tracking state, turns device messages into pending ingest events and uploads them.
/// iOS counterpart of the Android `TrackingController`. Main thread only.
final class TrackingController {
  static let shared = TrackingController()

  let credentials = CredentialStore()
  let store = PendingEventStore.shared
  private(set) lazy var uploader = IngestUploader(credentials: credentials, store: store)

  private var bleManager: BleConnectionManager!
  private var flutterApi: TrackingFlutterApi?
  private var cachedCredentials: StoredCredentials?

  private var connectionState: TrackingConnectionState = .idle
  private var todayPuffCount = 0
  private var todayPuffDay = Calendar.current.startOfDay(for: Date())
  private var batteryPercent: Int?
  private var liquidPercent: Int?
  private var isCharging: Bool?
  private var lastError: String?

  private var lastPersistedStatus: DeviceStatus?
  private var flushTask: Task<Void, Never>?
  private var flushPending = false
  private var heartbeatTimer: Timer?
  private var resumeObserver: NSObjectProtocol?

  private init() {
    cachedCredentials = credentials.get()
    bleManager = BleConnectionManager(
      onState: { [weak self] state, error in self?.onConnectionState(state, error) },
      onMessage: { [weak self] message in self?.handleMessage(message) }
    )
    bleManager.setSimulation(credentials.simulationEnabled)
    bleManager.setTargetAddress(credentials.pairedBleAddress)
    resumeObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.resumeBleIfConfigured()
    }
  }

  func setFlutterApi(_ api: TrackingFlutterApi?) {
    flutterApi = api
    publishState()
  }

  func setNativeCredentials(_ creds: NativeCredentials) {
    let stored = StoredCredentials(
      baseUrl: creds.baseUrl,
      deviceId: creds.deviceId,
      deviceToken: creds.deviceToken,
      hardwareId: creds.hardwareId
    )
    credentials.save(stored)
    cachedCredentials = stored
    lastError = nil
    requestFlush()
  }

  func setPairedAddress(_ address: String?) {
    credentials.pairedBleAddress = address
    bleManager.setTargetAddress(address)
  }

  func activeDeviceId() -> String? { cachedCredentials?.deviceId }

  func clearCredentials() {
    stopTrackingInternal()
    credentials.clear()
    cachedCredentials = nil
  }

  func startTracking() {
    credentials.trackingEnabled = true
    bleManager.setSimulation(credentials.simulationEnabled)
    if CBManager.authorization == .denied || CBManager.authorization == .restricted {
      lastError = "Tracking benötigt Bluetooth — in den iOS-Einstellungen für Vapen erlauben."
    }
    bleManager.ensureConnected()
    publishState()
    requestFlush()
  }

  /// App launch / resume / BLE relaunch: reconnect without toggling the tracking flag.
  func resumeBleIfConfigured() {
    guard credentials.trackingEnabled else { return }
    guard credentials.pairedBleAddress != nil || credentials.simulationEnabled else { return }
    bleManager.ensureConnected()
    requestFlush()
  }

  func stopTracking() {
    credentials.trackingEnabled = false
    stopTrackingInternal()
    publishState()
  }

  private func stopTrackingInternal() {
    bleManager.disconnect()
    connectionState = .idle
  }

  func getState() -> TrackingState {
    TrackingState(
      enabled: credentials.trackingEnabled,
      connectionState: connectionState,
      batteryPercent: batteryPercent.map(Int64.init),
      liquidPercent: liquidPercent.map(Int64.init),
      isCharging: isCharging,
      todayPuffCount: Int64(currentTodayPuffCount()),
      pendingUploads: Int64(pendingCount()),
      lastError: lastError,
      simulationEnabled: credentials.simulationEnabled
    )
  }

  func pendingCount() -> Int { store.count() }

  func setSimulationEnabled(_ enabled: Bool) {
    credentials.simulationEnabled = enabled
    bleManager.setSimulation(enabled)
    if credentials.trackingEnabled {
      bleManager.disconnect()
      bleManager.connect()
    }
    publishState()
  }

  // MARK: - Device messages

  private func onConnectionState(_ state: TrackingConnectionState, _ error: String?) {
    let wasLive = connectionState == .live
    connectionState = state
    lastError = error
    let isLive = state == .live
    if wasLive != isLive { persistBridgeLink(isLive) }
    updateLinkHeartbeat(credentials.trackingEnabled && isLive)
    publishState()
  }

  /// Called on the main thread in device order.
  private func handleMessage(_ message: DeviceMessage) {
    let hardwareId = cachedCredentials?.hardwareId ?? bleManager.hardwareId()
    switch message {
    case .puffStarted, .puffDetected, .unknown:
      break
    case let .puffCompleted(startedAt, durationMs, deviceIndex, raw):
      persistPuff(hardwareId, startedAt, durationMs, deviceIndex, raw, source: "live")
      todayPuffCount = currentTodayPuffCount() + 1
      todayPuffDay = Calendar.current.startOfDay(for: Date())
      let puff = PuffInfo(startedAtEpochMs: startedAt.epochMs, durationMs: Int64(durationMs))
      flutterApi?.onPuff(puff: puff) { _ in }
      publishState()
      requestFlush()
    case let .historyPuff(startedAt, durationMs, deviceIndex, raw):
      persistPuff(hardwareId, startedAt, durationMs, deviceIndex, raw, source: "history")
      requestFlush()
    case let .dailyPuffCount(today, _):
      todayPuffCount = today
      todayPuffDay = Calendar.current.startOfDay(for: Date())
      publishState()
    case let .status(status):
      if let battery = status.battery { batteryPercent = battery }
      if let liquid = status.liquid { liquidPercent = liquid }
      if let charging = status.charging { isCharging = charging }
      if shouldPersist(status) {
        persistStatus(hardwareId, status)
        lastPersistedStatus = status
        requestFlush()
      }
      let info = StatusInfo(
        batteryPercent: batteryPercent.map(Int64.init),
        liquidPercent: liquidPercent.map(Int64.init),
        isCharging: isCharging,
        recordedAtEpochMs: status.recordedAt.epochMs
      )
      flutterApi?.onStatus(status: info) { _ in }
      publishState()
    case let .deviceAlert(code, _):
      if let text = Self.alertText(code) {
        lastError = text
        publishState()
      }
    case let .warning(text):
      lastError = text
      publishState()
    }
  }

  /// The counter belongs to a calendar day; after midnight it starts at 0 until the device reports again.
  private func currentTodayPuffCount() -> Int {
    todayPuffDay == Calendar.current.startOfDay(for: Date()) ? todayPuffCount : 0
  }

  private func shouldPersist(_ status: DeviceStatus) -> Bool {
    guard let last = lastPersistedStatus else { return true }
    let changed = status.battery != last.battery
      || status.liquid != last.liquid
      || status.charging != last.charging
      || status.childLock != last.childLock
      || status.firmware != last.firmware
    let stale = status.recordedAt.timeIntervalSince(last.recordedAt) >= Self.statusHeartbeatSeconds
    return changed || stale
  }

  private static func alertText(_ code: Int) -> String? {
    switch code {
    case 1: return "Elfbar: Akku schwach"
    case 2: return "Elfbar: Liquid fast leer"
    case 3: return "Elfbar: überhitzt"
    case 4: return "Elfbar: Kurzschluss am Pod"
    case 5: return "Elfbar: Pod nicht erkannt"
    case 6: return "Elfbar: Tageslimit erreicht"
    default: return nil
    }
  }

  // MARK: - Upload

  /// Uploads everything pending; coalesces bursts (e.g. a history sync).
  private func requestFlush() {
    flushPending = true
    if flushTask != nil { return }
    flushTask = Task { [weak self] in
      let activity = BackgroundActivity.begin("vapen.upload")
      await self?.runFlushLoop()
      activity.end()
    }
  }

  private func runFlushLoop() async {
    let uploader = await MainActor.run { self.uploader }
    while await MainActor.run(body: { self.takeFlushRequest() }) {
      await sleepMs(Self.flushDebounceMs)
      for _ in 0..<Self.maxFlushBatches {
        let result = await uploader.flush()
        let keepGoing = await MainActor.run { self.applyFlushResult(result) }
        if !keepGoing { return }
      }
    }
  }

  /// Consumes a pending flush request; clears the running task when there is none.
  private func takeFlushRequest() -> Bool {
    if flushPending {
      flushPending = false
      return true
    }
    flushTask = nil
    publishState()
    return false
  }

  /// Returns whether the flush loop should send the next batch.
  private func applyFlushResult(_ result: UploadResult) -> Bool {
    switch result {
    case .success:
      if lastError?.hasPrefix(Self.uploadErrorPrefix) == true { lastError = nil }
      return true
    case .nothingToSend:
      flushTask = nil
      publishState()
      return false
    default:
      noteUploadFailure(result)
      // Nothing else triggers a flush until the next puff; let iOS retry in the background.
      UploadScheduler.enqueue()
      flushTask = nil
      return false
    }
  }

  private func noteUploadFailure(_ result: UploadResult) {
    switch result {
    case .noCredentials:
      lastError = "Upload: kein Gerät-Token — unter Mehr → Geräte erneut koppeln."
    case .authError:
      lastError = "Upload abgelehnt (Token ungültig). Gerät in der App erneut koppeln."
    case .serverError:
      lastError = "Upload: Server-Fehler — später erneut versuchen."
    case .rateLimited:
      lastError = "Upload: Rate-Limit — bitte kurz warten."
    case .networkError:
      lastError = "Upload: keine Verbindung zum Server — wird automatisch wiederholt."
    case let .otherError(code, body):
      lastError = "Upload fehlgeschlagen (HTTP \(code)): \(body.prefix(120))"
    case .success, .nothingToSend:
      break
    }
    publishState()
  }

  // MARK: - Pending events

  private func persistPuff(
    _ hardwareId: String,
    _ startedAt: Date,
    _ durationMs: Int,
    _ deviceIndex: Int64?,
    _ raw: [UInt8],
    source: String
  ) {
    let id = EventIdFactory.puffId(hardwareId: hardwareId, deviceIndex: deviceIndex, startedAt: startedAt)
    insert(id, type: "puff", createdAt: Date(), payload: [
      "type": "puff",
      "client_event_id": id,
      "started_at": ISO8601DateFormatter.vapen.string(from: startedAt),
      "duration_ms": durationMs,
      "source": source,
      "raw": ["hex": raw.hexString],
    ])
  }

  private func persistBridgeLink(_ connected: Bool) {
    let hardwareId = cachedCredentials?.hardwareId ?? bleManager.hardwareId()
    let recordedAt = Date()
    let id = EventIdFactory.bridgeLinkId(hardwareId: hardwareId, recordedAt: recordedAt)
    var payload: [String: Any] = [
      "type": "status",
      "client_event_id": id,
      "recorded_at": ISO8601DateFormatter.vapen.string(from: recordedAt),
      "ble_connected": connected,
    ]
    if let batteryPercent { payload["battery_percent"] = batteryPercent }
    if let isCharging { payload["is_charging"] = isCharging }
    if let liquidPercent { payload["liquid_percent"] = liquidPercent }
    insert(id, type: "status", createdAt: recordedAt, payload: payload)
    requestFlush()
  }

  private func persistStatus(_ hardwareId: String, _ status: DeviceStatus) {
    let id = EventIdFactory.statusId(hardwareId: hardwareId, recordedAt: status.recordedAt)
    var payload: [String: Any] = [
      "type": "status",
      "client_event_id": id,
      "recorded_at": ISO8601DateFormatter.vapen.string(from: status.recordedAt),
    ]
    if let battery = status.battery { payload["battery_percent"] = battery }
    if let charging = status.charging { payload["is_charging"] = charging }
    if let liquid = status.liquid { payload["liquid_percent"] = liquid }
    if let counter = status.counterTotal { payload["puff_counter_total"] = counter }
    if let mode = status.powerMode { payload["power_mode"] = mode }
    if let lock = status.childLock { payload["child_lock"] = lock }
    if let firmware = status.firmware { payload["firmware_version"] = firmware }
    insert(id, type: "status", createdAt: Date(), payload: payload)
  }

  private func insert(_ id: String, type: String, createdAt: Date, payload: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
    store.insert(
      PendingEvent(
        clientEventId: id,
        type: type,
        payloadJson: String(decoding: data, as: UTF8.self),
        createdAtEpochMs: createdAt.epochMs
      )
    )
  }

  private func updateLinkHeartbeat(_ active: Bool) {
    heartbeatTimer?.invalidate()
    heartbeatTimer = nil
    guard active else { return }
    heartbeatTimer = Timer.scheduledTimer(withTimeInterval: Self.bridgeHeartbeatSeconds, repeats: true) { [weak self] timer in
      guard let self, self.connectionState == .live else {
        timer.invalidate()
        return
      }
      self.persistBridgeLink(true)
    }
  }

  private func publishState() {
    flutterApi?.onTrackingStateChanged(state: getState()) { _ in }
  }

  private static let bridgeHeartbeatSeconds: TimeInterval = 45
  private static let statusHeartbeatSeconds: TimeInterval = 15 * 60
  private static let flushDebounceMs: Int64 = 500
  private static let maxFlushBatches = 50
  private static let uploadErrorPrefix = "Upload"
}
