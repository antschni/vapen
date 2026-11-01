import CoreBluetooth
import Foundation

/// Raw BLE scanner/logger for reverse engineering. Main thread only; `address` is the
/// CoreBluetooth peripheral identifier.
final class BleExplorerManager: NSObject {
  private let flutterApi: TrackingFlutterApi?
  private var central: CBCentralManager?
  private var log: [[String: Any]] = []
  private var discovered: [UUID: CBPeripheral] = [:]
  private var peripheral: CBPeripheral?
  private var activeFilter = ExplorerScanFilter()
  private var scanRequested = false
  private var connectRequested: UUID?

  init(flutterApi: TrackingFlutterApi?) {
    self.flutterApi = flutterApi
  }

  func startScan(_ filter: ExplorerScanFilter) {
    activeFilter = filter
    scanRequested = true
    let central = ensureCentral()
    guard checkReady(central, .scan) else { return }
    central.stopScan()
    emit(.scan, note: "scan start")
    central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
  }

  func stopScan() {
    scanRequested = false
    if let central, central.state == .poweredOn { central.stopScan() }
    emit(.scan, note: "scan stop")
  }

  func connect(_ address: String) {
    let central = ensureCentral()
    guard let identifier = UUID(uuidString: address) else {
      emit(.connect, note: "ungültige Geräte-ID: \(address)")
      return
    }
    connectRequested = identifier
    guard checkReady(central, .connect) else { return }
    guard let target = discovered[identifier] ?? central.retrievePeripherals(withIdentifiers: [identifier]).first else {
      emit(.connect, note: "Gerät \(address) unbekannt — zuerst scannen.")
      return
    }
    connectRequested = nil
    emit(.connect, note: address)
    if let old = peripheral, old !== target { central.cancelPeripheralConnection(old) }
    peripheral = target
    target.delegate = self
    central.connect(target, options: nil)
  }

  func disconnect() {
    connectRequested = nil
    if let central, let peripheral { central.cancelPeripheralConnection(peripheral) }
    peripheral = nil
    emit(.disconnect, note: "")
  }

  func write(serviceUuid: String, charUuid: String, hex: String, withResponse: Bool) {
    guard let p = peripheral,
          let service = p.services?.first(where: { $0.uuid == CBUUID(string: serviceUuid) }),
          let characteristic = service.characteristics?.first(where: { $0.uuid == CBUUID(string: charUuid) }),
          let bytes = Self.parseHex(hex)
    else { return }
    p.writeValue(Data(bytes), for: characteristic, type: withResponse ? .withResponse : .withoutResponse)
    emit(.write, serviceUuid: serviceUuid, charUuid: charUuid, hex: hex, note: "withResponse=\(withResponse)")
  }

  func addMarker(_ note: String) {
    emit(.marker, hex: "", note: note)
  }

  func exportLog() throws -> String {
    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("explorer", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("ble-explorer-\(Int(Date().timeIntervalSince1970)).jsonl")
    let lines = try log.map { entry -> String in
      let data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
      return String(decoding: data, as: UTF8.self)
    }
    try lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
    return file.path
  }

  private func ensureCentral() -> CBCentralManager {
    if let central { return central }
    let created = CBCentralManager(delegate: self, queue: .main)
    central = created
    return created
  }

  /// Emits a hint and returns false unless Bluetooth is usable; requests resume on power-on.
  private func checkReady(_ central: CBCentralManager, _ direction: ExplorerDirection) -> Bool {
    switch central.state {
    case .poweredOn:
      return true
    case .unauthorized:
      emit(direction, note: "Bluetooth-Berechtigung fehlt — in den iOS-Einstellungen für Vapen erlauben.")
    case .poweredOff:
      emit(direction, note: "Bluetooth ist aus — bitte einschalten.")
    case .unsupported:
      emit(direction, note: "BLE wird auf diesem Gerät nicht unterstützt.")
    default:
      break
    }
    return false
  }

  private func emit(
    _ direction: ExplorerDirection,
    serviceUuid: String? = nil,
    charUuid: String? = nil,
    hex: String = "",
    note: String? = nil
  ) {
    let now = Date()
    let timestamp = ISO8601DateFormatter.vapen.string(from: now)
    log.append([
      "ts": timestamp,
      "direction": Self.name(direction),
      "service_uuid": Self.jsonValue(serviceUuid),
      "char_uuid": Self.jsonValue(charUuid),
      "hex": hex,
      "note": Self.jsonValue(note),
    ])
    let event = ExplorerEvent(
      epochMs: now.epochMs,
      direction: direction,
      serviceUuid: serviceUuid,
      charUuid: charUuid,
      hex: hex,
      note: note
    )
    flutterApi?.onExplorerEvent(event: event) { _ in }
  }

  private static func jsonValue(_ value: String?) -> Any {
    if let value { return value }
    return NSNull()
  }

  private static func name(_ direction: ExplorerDirection) -> String {
    switch direction {
    case .read: return "READ"
    case .write: return "WRITE"
    case .notify: return "NOTIFY"
    case .indicate: return "INDICATE"
    case .scan: return "SCAN"
    case .connect: return "CONNECT"
    case .disconnect: return "DISCONNECT"
    case .marker: return "MARKER"
    }
  }

  static func parseHex(_ hex: String) -> [UInt8]? {
    let digits = Array(hex.replacingOccurrences(of: " ", with: ""))
    guard digits.count % 2 == 0 else { return nil }
    var out: [UInt8] = []
    out.reserveCapacity(digits.count / 2)
    var index = 0
    while index < digits.count {
      guard let byte = UInt8(String(digits[index...index + 1]), radix: 16) else { return nil }
      out.append(byte)
      index += 2
    }
    return out
  }
}

extension BleExplorerManager: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard central.state == .poweredOn else {
      if scanRequested { _ = checkReady(central, .scan) }
      return
    }
    if scanRequested { startScan(activeFilter) }
    if let pending = connectRequested { connect(pending.uuidString) }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let rssi = RSSI.intValue
    let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String).flatMap { $0.isEmpty ? nil : $0 }
      ?? peripheral.name
    if let minRssi = activeFilter.minRssi, Int64(rssi) < minRssi { return }
    if let filter = activeFilter.nameContains,
       name?.range(of: filter, options: .caseInsensitive) == nil { return }
    discovered[peripheral.identifier] = peripheral
    let manufacturer = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)?.hexString ?? ""
    emit(.scan, hex: manufacturer, note: "\(peripheral.identifier.uuidString) rssi=\(rssi) name=\(name ?? "?")")
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    guard peripheral === self.peripheral else { return }
    peripheral.discoverServices(nil)
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    emit(.disconnect, note: "connect failed: \(error?.localizedDescription ?? "-")")
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    emit(.disconnect, note: "error=\(error?.localizedDescription ?? "-")")
  }
}

extension BleExplorerManager: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error {
      emit(.read, note: "service discovery failed: \(error.localizedDescription)")
      return
    }
    peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    for characteristic in service.characteristics ?? [] {
      let props = characteristic.properties
      if props.contains(.notify) || props.contains(.indicate) {
        peripheral.setNotifyValue(true, for: characteristic)
      }
      emit(
        .read,
        serviceUuid: service.uuid.uuidString.lowercased(),
        charUuid: characteristic.uuid.uuidString.lowercased(),
        hex: "",
        note: "props=\(props.rawValue)"
      )
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let value = characteristic.value else { return }
    emit(
      .notify,
      serviceUuid: characteristic.service?.uuid.uuidString.lowercased(),
      charUuid: characteristic.uuid.uuidString.lowercased(),
      hex: value.hexString
    )
  }
}

extension ISO8601DateFormatter {
  /// RFC 3339 UTC with milliseconds, e.g. `2026-10-04T18:00:00.000Z`.
  static let vapen: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
}
