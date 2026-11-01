import CryptoKit
import Foundation

/// Deterministic client_event_id (UUIDv5). Namespace and rules documented in docs/elfbar-protocol.md;
/// must produce the same ids as the Android `EventIdFactory`.
enum EventIdFactory {
  private static let namespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!

  static func puffId(hardwareId: String, deviceIndex: Int64?, startedAt: Date) -> String {
    if let deviceIndex {
      return uuidV5("\(hardwareId):puff:\(deviceIndex)")
    }
    let ms = (startedAt.epochMs / 100) * 100
    return uuidV5("\(hardwareId):puff:\(ms)")
  }

  static func statusId(hardwareId: String, recordedAt: Date) -> String {
    uuidV5("\(hardwareId):status:\(epochSecond(recordedAt) / 60)")
  }

  /// 30s buckets so bridge heartbeats dedupe within the same window.
  static func bridgeLinkId(hardwareId: String, recordedAt: Date) -> String {
    uuidV5("\(hardwareId):ble_link:\(epochSecond(recordedAt) / 30)")
  }

  static func puffStartedId(hardwareId: String, occurredAt: Date) -> String {
    uuidV5("\(hardwareId):puff_started:\(epochSecond(occurredAt))")
  }

  private static func epochSecond(_ date: Date) -> Int64 {
    Int64(date.timeIntervalSince1970.rounded(.down))
  }

  /// Lower-case like `java.util.UUID.toString()`.
  static func uuidV5(_ name: String) -> String {
    var input = withUnsafeBytes(of: namespace.uuid) { Data($0) }
    input.append(Data(name.utf8))
    var hash = Array(Insecure.SHA1.hash(data: input).prefix(16))
    hash[6] = (hash[6] & 0x0F) | 0x50
    hash[8] = (hash[8] & 0x3F) | 0x80
    let uuid = UUID(uuid: (
      hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
      hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]
    ))
    return uuid.uuidString.lowercased()
  }
}
