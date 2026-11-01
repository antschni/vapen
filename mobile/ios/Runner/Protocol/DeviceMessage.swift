import CoreBluetooth

struct DeviceStatus: Equatable {
  var battery: Int?
  var charging: Bool?
  var liquid: Int?
  var counterTotal: Int64?
  var powerMode: String?
  var childLock: Bool?
  var firmware: String?
  var recordedAt: Date
}

enum DeviceMessage {
  case puffStarted(at: Date)

  /// Device signalled a finished puff; the exact record arrives via the next history sync.
  case puffDetected(at: Date, durationMs: Int)

  case puffCompleted(startedAt: Date, durationMs: Int, deviceIndex: Int64?, raw: [UInt8])
  case historyPuff(startedAt: Date, durationMs: Int, deviceIndex: Int64?, raw: [UInt8])
  case dailyPuffCount(today: Int, at: Date)
  case status(DeviceStatus)
  case deviceAlert(code: Int, at: Date)
  case warning(String)
  case unknown(characteristic: CBUUID, raw: [UInt8])

  var isPuffRecord: Bool {
    switch self {
    case .puffCompleted, .historyPuff: return true
    default: return false
    }
  }
}

struct ProtocolError: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

struct Advertisement {
  let name: String?
  let address: String
  let rssi: Int
}

/// `address` is the CoreBluetooth peripheral identifier — iOS does not expose the BLE MAC.
struct DeviceInfo {
  let serialNumber: String?
  let address: String
}

/// Phone identity sent with FIRST_LINK_INFO; the device remembers it to skip re-confirmation.
struct ClientIdentity {
  let name: String
  let id: String
}

protocol VapeProtocol: AnyObject {
  var model: String { get }

  /// Wall-clock time of the last frame received from the device; 0 if unknown.
  var lastFrameAtMillis: Int64 { get }

  func matches(_ advertisement: Advertisement) -> Bool

  /// Selects per-device persisted state (history cursor, link flag).
  func bindDevice(_ deviceKey: String)

  /// Subscribes, runs the vendor handshake and returns initial messages. Throws `ProtocolError`.
  func initialize(session: GattSession, profile: BleProfile) async throws -> [DeviceMessage]

  /// Must be called for every notification, synchronously and in arrival order.
  func onNotification(characteristic: CBUUID, value: Data, receivedAtMillis: Int64) -> [DeviceMessage]

  func requestStatus(session: GattSession, profile: BleProfile) async -> [DeviceMessage]

  /// Fetches puff records not yet seen.
  func syncHistory(session: GattSession, profile: BleProfile) async -> [DeviceMessage]

  func hardwareId(_ info: DeviceInfo) -> String
}
