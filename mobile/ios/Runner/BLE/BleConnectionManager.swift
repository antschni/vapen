import CoreBluetooth
import UIKit

/// Keeps the tracking link to the paired Elfbar. iOS counterpart of the Android
/// `BleConnectionManager`, adapted to CoreBluetooth:
///
/// - Connections are requested with `connect`, which never times out on iOS. After a live link
///   drops, a new pending connection is issued right away so iOS reconnects as soon as the device
///   is back in range — also while the app is suspended (`bluetooth-central` background mode).
/// - The central uses state restoration, so iOS relaunches the app for BLE events after it was
///   terminated for memory.
///
/// All mutable state is confined to `queue`, which is also the CoreBluetooth delegate queue.
/// `onState` and `onMessage` are invoked on the main thread, messages in device order.
final class BleConnectionManager: NSObject {
  typealias StateHandler = (TrackingConnectionState, String?) -> Void
  typealias MessageHandler = (DeviceMessage) -> Void

  static let restoreIdentifier = "dev.vapen.tracking.central"

  private let queue = DispatchQueue(label: "dev.vapen.ble.tracking")
  private let ops = GattOperationQueue()
  private let cursorStore = UserDefaultsHistoryCursorStore()
  private let identity: ClientIdentity
  private let onState: StateHandler
  private let onMessage: MessageHandler

  private var central: CBCentralManager?
  private var peripheral: CBPeripheral?
  private var restoredPeripherals: [CBPeripheral] = []
  private var session: CoreBluetoothGattSession?
  private var protocolImpl: VapeProtocol
  private var linkTask: Task<Void, Never>?
  private var syncRequests: AsyncStream<Void>.Continuation?
  private var simulationTask: Task<Void, Never>?
  private var watchdog: DispatchWorkItem?
  private var reconnectWork: DispatchWorkItem?
  /// Bumped whenever a link starts or is torn down; late callbacks of an old link are ignored.
  private var generation = 0
  private var pendingCharacteristicDiscoveries = 0
  private var scanningForTarget = false
  private var wantsConnection = false
  /// We cancelled the connection ourselves; the matching didDisconnect is expected.
  private var awaitingCancel = false
  /// Reconnect to issue once `awaitingCancel` resolves (`true` = immediately, `false` = backoff).
  private var reconnectAfterCancel: Bool?
  private var backoffMs: Int64 = 1_000
  private var state: TrackingConnectionState = .idle
  private var targetAddress: String?
  private var simulation = false

  /// Must be created on the main thread (reads `UIDevice`).
  init(onState: @escaping StateHandler, onMessage: @escaping MessageHandler) {
    self.onState = onState
    self.onMessage = onMessage
    let device = UIDevice.current
    identity = ClientIdentity(
      name: device.name.isBlank ? "iPhone" : device.name,
      id: device.identifierForVendor?.uuidString ?? "vapen"
    )
    protocolImpl = SimulatedProtocol()
    super.init()
    protocolImpl = createDeviceProtocol()
  }

  // MARK: - Public API (any thread)

  func setSimulation(_ enabled: Bool) {
    queue.async { [self] in
      simulation = enabled
      if !enabled { simulationTask?.cancel() }
      protocolImpl = enabled ? SimulatedProtocol() : createDeviceProtocol()
    }
  }

  func setTargetAddress(_ address: String?) {
    queue.async { [self] in targetAddress = address }
  }

  /// Connects unless a link is already up or being set up. App start and resume both call this;
  /// a plain `connect` would tear down a working link and force a new handshake.
  func ensureConnected() {
    queue.async { [self] in
      if Self.activeStates.contains(state) { return }
      backoffMs = 1_000
      connectLocked()
    }
  }

  func connect() {
    queue.async { [self] in connectLocked() }
  }

  func disconnect() {
    queue.async { [self] in
      wantsConnection = false
      cancelReconnect()
      stopTargetScan()
      simulationTask?.cancel()
      simulationTask = nil
      teardownLink()
      cancelConnection(thenReconnect: nil)
      publish(.disconnected, nil)
    }
  }

  func hardwareId() -> String {
    queue.sync {
      protocolImpl.hardwareId(DeviceInfo(serialNumber: nil, address: targetAddress ?? "sim"))
    }
  }

  // MARK: - Connection lifecycle (on `queue`)

  private func publish(_ newState: TrackingConnectionState, _ error: String?) {
    state = newState
    let handler = onState
    DispatchQueue.main.async { handler(newState, error) }
  }

  private func emit(_ messages: [DeviceMessage]) {
    guard !messages.isEmpty else { return }
    let handler = onMessage
    DispatchQueue.main.async { messages.forEach(handler) }
  }

  private func ensureCentral() -> CBCentralManager {
    if let central { return central }
    let created = CBCentralManager(
      delegate: self,
      queue: queue,
      options: [
        CBCentralManagerOptionRestoreIdentifierKey: Self.restoreIdentifier,
        CBCentralManagerOptionShowPowerAlertKey: false,
      ]
    )
    central = created
    return created
  }

  private func connectLocked() {
    if simulation {
      cancelReconnect()
      teardownLink()
      publish(.live, nil)
      startSimulationFeed()
      return
    }
    guard let address = targetAddress, let identifier = UUID(uuidString: address) else {
      wantsConnection = false
      publish(.waiting, "Kein Gerät gekoppelt — unter Geräte erneut koppeln.")
      return
    }
    wantsConnection = true
    let central = ensureCentral()
    switch central.state {
    case .poweredOn:
      break
    case .poweredOff:
      // centralManagerDidUpdateState resumes once Bluetooth is back on.
      publish(.disconnected, "Bluetooth aus")
      return
    case .unauthorized:
      publish(.disconnected, "Bluetooth-Berechtigung fehlt (Einstellungen → Vapen → Bluetooth).")
      return
    case .unsupported:
      publish(.disconnected, "Bluetooth LE wird auf diesem Gerät nicht unterstützt.")
      return
    default:
      publish(.waiting, nil)
      return
    }

    cancelReconnect()
    stopTargetScan()
    protocolImpl.bindDevice(address.uppercased())
    guard let target = resolvePeripheral(central, identifier) else {
      // Not in this phone's Bluetooth cache (e.g. after a Bluetooth reset): look for it.
      teardownLink()
      scanningForTarget = true
      central.scanForPeripherals(withServices: nil, options: nil)
      publish(.waiting, "Suche Elfbar — Display einschalten und nah ans Telefon halten.")
      return
    }
    connectPeripheral(target, central)
  }

  private func resolvePeripheral(_ central: CBCentralManager, _ identifier: UUID) -> CBPeripheral? {
    if let current = peripheral, current.identifier == identifier { return current }
    if let restored = restoredPeripherals.first(where: { $0.identifier == identifier }) { return restored }
    if let known = central.retrievePeripherals(withIdentifiers: [identifier]).first { return known }
    return central.retrieveConnectedPeripherals(withServices: [BleConstants.cigService])
      .first { $0.identifier == identifier }
  }

  private func connectPeripheral(_ target: CBPeripheral, _ central: CBCentralManager) {
    if let old = peripheral, old !== target, old.state != .disconnected {
      central.cancelPeripheralConnection(old)
    }
    if peripheral !== target { awaitingCancel = false }
    peripheral = target
    target.delegate = self
    session = CoreBluetoothGattSession(peripheral: target, queue: queue, ops: ops)

    if awaitingCancel {
      // Our own cancel is still in flight; reconnect once it is confirmed.
      reconnectAfterCancel = true
      publish(.connecting, nil)
      return
    }
    switch target.state {
    case .connected:
      // Restored by iOS, or reconnect requested on a live link: redo discovery and handshake.
      didConnectLocked(target)
    default:
      teardownLink()
      publish(.connecting, nil)
      central.connect(target, options: nil)
      // iOS keeps the request pending without timeout; only report that the device is not around.
      armWatchdog(Self.connectTimeoutMs) { [weak self] in
        self?.publish(.waiting, "Elfbar nicht erreichbar — Display einschalten, InnoGate schließen. Verbindet automatisch.")
      }
    }
  }

  private func didConnectLocked(_ target: CBPeripheral) {
    teardownLink()
    publish(.discovering, nil)
    armWatchdog(Self.discoveryTimeoutMs) { [weak self] in
      self?.failAndReconnect("Dienstsuche hängt — Elfbar wach halten (Display an).")
    }
    pendingCharacteristicDiscoveries = 0
    target.discoverServices(nil)
  }

  private func finishDiscovery(_ target: CBPeripheral) {
    guard let profile = BleProfileDetector.detect(target) else {
      let uuids = (target.services ?? []).map { $0.uuid.uuidString }.joined(separator: ", ")
      failAndReconnect("Kein ELFA-MASTER-Dienst gefunden: \(uuids)", reconnect: false)
      return
    }
    guard let session else { return }
    armWatchdog(Self.handshakeTimeoutMs) { [weak self] in
      self?.failAndReconnect("Elfbar antwortet nicht — InnoGate schließen und Kopplung am Gerät bestätigen.")
    }
    publish(.initializing, nil)
    let gen = generation
    let proto = protocolImpl
    linkTask = Task { [weak self] in
      do {
        let initial = try await proto.initialize(session: session, profile: profile)
        self?.queue.async { self?.handshakeSucceeded(gen, session, profile, initial) }
      } catch {
        let message = error.localizedDescription
        self?.queue.async {
          guard let self, self.generation == gen else { return }
          self.failAndReconnect(message)
        }
      }
    }
  }

  private func handshakeSucceeded(_ gen: Int, _ session: GattSession, _ profile: BleProfile, _ initial: [DeviceMessage]) {
    guard gen == generation else { return }
    cancelWatchdog()
    backoffMs = 1_000
    publish(.live, nil)
    emit(initial)
    startLinkJobs(gen, session, profile)
  }

  /// Drops the current link attempt or link and, unless told otherwise, schedules a reconnect.
  private func failAndReconnect(_ message: String?, reconnect: Bool = true) {
    // A live link that dropped is re-requested right away: iOS then connects on its own once the
    // device is reachable. Failures while setting up back off instead of looping.
    let immediate = state == .live
    teardownLink()
    publish(.disconnected, message)
    cancelConnection(thenReconnect: reconnect ? immediate : nil)
  }

  /// Cancels the peripheral connection if one exists; the reconnect runs after iOS confirms it.
  private func cancelConnection(thenReconnect immediate: Bool?) {
    if let p = peripheral, let central, p.state == .connected || p.state == .connecting {
      awaitingCancel = true
      reconnectAfterCancel = immediate
      central.cancelPeripheralConnection(p)
      // Do not hang if iOS skips didDisconnect (possible for a connection that was still pending).
      queue.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
        guard let self, self.awaitingCancel, self.peripheral === p, p.state == .disconnected else { return }
        self.awaitingCancel = false
        let reconnect = self.reconnectAfterCancel
        self.reconnectAfterCancel = nil
        if let reconnect { self.scheduleReconnect(immediate: reconnect) }
      }
    } else if let immediate {
      scheduleReconnect(immediate: immediate)
    }
  }

  private func teardownLink() {
    generation += 1
    cancelWatchdog()
    stopLinkJobs()
    ops.failAll()
  }

  private func scheduleReconnect(immediate: Bool) {
    cancelReconnect()
    guard wantsConnection else { return }
    if immediate {
      connectLocked()
      return
    }
    let delay = backoffMs
    backoffMs = min(backoffMs * 2, 60_000)
    let work = DispatchWorkItem { [weak self] in self?.connectLocked() }
    reconnectWork = work
    queue.asyncAfter(deadline: .now() + .milliseconds(Int(delay)), execute: work)
  }

  private func cancelReconnect() {
    reconnectWork?.cancel()
    reconnectWork = nil
  }

  private func armWatchdog(_ timeoutMs: Int64, _ action: @escaping () -> Void) {
    watchdog?.cancel()
    let gen = generation
    let work = DispatchWorkItem { [weak self] in
      guard let self, self.generation == gen else { return }
      action()
    }
    watchdog = work
    queue.asyncAfter(deadline: .now() + .milliseconds(Int(timeoutMs)), execute: work)
  }

  private func cancelWatchdog() {
    watchdog?.cancel()
    watchdog = nil
  }

  private func stopTargetScan() {
    if scanningForTarget, let central, central.state == .poweredOn {
      central.stopScan()
    }
    scanningForTarget = false
  }

  // MARK: - Link jobs

  /// Runs for the lifetime of one established link: initial sync, puff-triggered syncs, periodic polling.
  private func startLinkJobs(_ gen: Int, _ session: GattSession, _ profile: BleProfile) {
    stopLinkJobs()
    var continuation: AsyncStream<Void>.Continuation?
    let requests = AsyncStream<Void>(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
    guard let requestSync = continuation else { return }
    syncRequests = requestSync
    let proto = protocolImpl
    linkTask = Task { [weak self] in
      guard let self else { return }
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          await self.runSyncLoop(session, profile, proto, requests)
        }
        group.addTask {
          await self.runPollLoop(gen, session, profile, proto, requestSync)
        }
      }
    }
  }

  private func stopLinkJobs() {
    linkTask?.cancel()
    linkTask = nil
    syncRequests?.finish()
    syncRequests = nil
  }

  private func runSyncLoop(
    _ session: GattSession,
    _ profile: BleProfile,
    _ proto: VapeProtocol,
    _ requests: AsyncStream<Void>
  ) async {
    emit(await proto.requestStatus(session: session, profile: profile))
    emit(await proto.syncHistory(session: session, profile: profile))
    for await _ in requests {
      if Task.isCancelled { return }
      // A puff push may wake the suspended app for only a few seconds.
      let activity = BackgroundActivity.begin("vapen.puff-sync")
      await sleepMs(Self.puffSyncDelayMs)
      var found = await syncPuffs(session, profile, proto)
      if !found && !Task.isCancelled {
        await sleepMs(Self.puffSyncRetryMs)
        found = await syncPuffs(session, profile, proto)
      }
      emit(await proto.requestStatus(session: session, profile: profile))
      activity.end()
    }
  }

  private func runPollLoop(
    _ gen: Int,
    _ session: GattSession,
    _ profile: BleProfile,
    _ proto: VapeProtocol,
    _ requestSync: AsyncStream<Void>.Continuation
  ) async {
    var tick = 0
    while !Task.isCancelled {
      await sleepMs(Self.statusPollMs)
      guard !Task.isCancelled, isCurrent(gen) else { return }
      emit(await proto.requestStatus(session: session, profile: profile))
      // iOS does not always report a dropped link; a silent device means a dead link.
      let lastFrame = proto.lastFrameAtMillis
      if lastFrame > 0 && nowEpochMs() - lastFrame > Self.linkStaleMs {
        queue.async { [weak self] in
          guard let self, self.generation == gen else { return }
          self.failAndReconnect("Elfbar antwortet nicht mehr — Verbindung wird neu aufgebaut.")
        }
        return
      }
      tick += 1
      if tick % Self.historyPollEveryNStatus == 0 { requestSync.yield(()) }
    }
  }

  private func isCurrent(_ gen: Int) -> Bool {
    queue.sync { generation == gen }
  }

  private func syncPuffs(_ session: GattSession, _ profile: BleProfile, _ proto: VapeProtocol) async -> Bool {
    let result = await proto.syncHistory(session: session, profile: profile)
    emit(result)
    return result.contains { $0.isPuffRecord }
  }

  private func startSimulationFeed() {
    guard let sim = protocolImpl as? SimulatedProtocol else { return }
    simulationTask?.cancel()
    simulationTask = Task { [weak self] in
      while !Task.isCancelled {
        await sleepMs(25_000)
        if Task.isCancelled { return }
        self?.emit([sim.nextSimulatedPuff(), sim.nextSimulatedStatus()])
      }
    }
  }

  private func createDeviceProtocol() -> VapeProtocol {
    let identity = self.identity
    return ElfbarMasterProtocol(identity: { identity }, cursorStore: cursorStore)
  }

  private func disconnectHint(_ error: Error?) -> String? {
    guard let error else { return nil }
    switch (error as? CBError)?.code {
    case .connectionTimeout?:
      return "Verbindung beendet — Elfbar wach halten (Display an)."
    case .peripheralDisconnected?:
      return "Gerät hat die Verbindung getrennt — InnoGate geschlossen?"
    default:
      return "BLE getrennt (\(error.localizedDescription))"
    }
  }

  private static let connectTimeoutMs: Int64 = 25_000
  private static let discoveryTimeoutMs: Int64 = 20_000
  /// FIRST_LINK_INFO may wait up to 60 s for on-device confirmation.
  private static let handshakeTimeoutMs: Int64 = 90_000
  private static let statusPollMs: Int64 = 60_000
  private static let historyPollEveryNStatus = 5
  private static let puffSyncDelayMs: Int64 = 1_500
  private static let puffSyncRetryMs: Int64 = 4_000
  private static let linkStaleMs: Int64 = 3 * statusPollMs + 30_000
  private static let activeStates: Set<TrackingConnectionState> = [.connecting, .discovering, .initializing, .live]
}

// MARK: - CBCentralManagerDelegate

extension BleConnectionManager: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      if wantsConnection && !Self.activeStates.contains(state) {
        backoffMs = 1_000
        connectLocked()
      }
    case .poweredOff, .resetting:
      // iOS drops every connection; peripheral objects must be retrieved again afterwards.
      scanningForTarget = false
      awaitingCancel = false
      reconnectAfterCancel = nil
      teardownLink()
      cancelReconnect()
      peripheral = nil
      restoredPeripherals = []
      if wantsConnection { publish(.disconnected, "Bluetooth aus") }
    case .unauthorized:
      if wantsConnection {
        publish(.disconnected, "Bluetooth-Berechtigung fehlt (Einstellungen → Vapen → Bluetooth).")
      }
    default:
      break
    }
  }

  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
    restoredPeripherals.forEach { $0.delegate = self }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    guard scanningForTarget,
          let address = targetAddress,
          peripheral.identifier.uuidString.caseInsensitiveCompare(address) == .orderedSame
    else { return }
    stopTargetScan()
    connectPeripheral(peripheral, central)
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    guard peripheral === self.peripheral, !awaitingCancel else { return }
    didConnectLocked(peripheral)
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    guard peripheral === self.peripheral, !awaitingCancel else { return }
    failAndReconnect("Verbindung fehlgeschlagen: \(error?.localizedDescription ?? "unbekannt")")
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    guard peripheral === self.peripheral else { return }
    if awaitingCancel {
      awaitingCancel = false
      let reconnect = reconnectAfterCancel
      reconnectAfterCancel = nil
      if let immediate = reconnect { scheduleReconnect(immediate: immediate) }
      return
    }
    failAndReconnect(disconnectHint(error))
  }
}

// MARK: - CBPeripheralDelegate

extension BleConnectionManager: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard peripheral === self.peripheral, peripheral.state == .connected else { return }
    if let error {
      failAndReconnect("Dienstsuche fehlgeschlagen (\(error.localizedDescription))")
      return
    }
    let wanted = (peripheral.services ?? []).filter {
      $0.uuid == BleConstants.cigService || $0.uuid == BleConstants.otaService
    }
    guard !wanted.isEmpty else {
      finishDiscovery(peripheral)
      return
    }
    pendingCharacteristicDiscoveries = wanted.count
    wanted.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard peripheral === self.peripheral, pendingCharacteristicDiscoveries > 0 else { return }
    pendingCharacteristicDiscoveries -= 1
    if pendingCharacteristicDiscoveries == 0 {
      finishDiscovery(peripheral)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    if ops.completeRead(characteristic.uuid, success: error == nil, data: characteristic.value) { return }
    guard peripheral === self.peripheral, error == nil, let value = characteristic.value else { return }
    let decoded = protocolImpl.onNotification(
      characteristic: characteristic.uuid,
      value: value,
      receivedAtMillis: nowEpochMs()
    )
    let puffDetected = decoded.contains {
      if case .puffDetected = $0 { return true }
      return false
    }
    if puffDetected { syncRequests?.yield(()) }
    emit(decoded)
  }

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    ops.completeWrite(error == nil)
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    ops.completeNotify(error == nil)
  }
}
