import Foundation

/// Position in the device's puff record list.
///
/// `tailDeviceSeconds` is the timestamp of the record at `nextOffset - 1`, used to detect that the
/// device list changed (cleared, rotated). `newestDeviceSeconds` is the newest record ever synced.
struct HistoryCursor: Equatable {
  var nextOffset = 0
  var tailDeviceSeconds: Int64 = 0
  var newestDeviceSeconds: Int64 = 0
  var linked = false
}

protocol HistoryCursorStore: AnyObject {
  func load(_ deviceKey: String) -> HistoryCursor
  func save(_ deviceKey: String, _ cursor: HistoryCursor)
}

final class InMemoryHistoryCursorStore: HistoryCursorStore {
  private let lock = NSLock()
  private var cursors: [String: HistoryCursor] = [:]

  func load(_ deviceKey: String) -> HistoryCursor {
    lock.lock()
    defer { lock.unlock() }
    return cursors[deviceKey] ?? HistoryCursor()
  }

  func save(_ deviceKey: String, _ cursor: HistoryCursor) {
    lock.lock()
    defer { lock.unlock() }
    cursors[deviceKey] = cursor
  }
}

final class UserDefaultsHistoryCursorStore: HistoryCursorStore {
  private let defaults: UserDefaults
  private let prefix = "vapen_history_cursor."

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load(_ deviceKey: String) -> HistoryCursor {
    let key = prefix + deviceKey
    return HistoryCursor(
      nextOffset: defaults.integer(forKey: "\(key).offset"),
      tailDeviceSeconds: (defaults.object(forKey: "\(key).tail") as? NSNumber)?.int64Value ?? 0,
      newestDeviceSeconds: (defaults.object(forKey: "\(key).newest") as? NSNumber)?.int64Value ?? 0,
      linked: defaults.bool(forKey: "\(key).linked")
    )
  }

  func save(_ deviceKey: String, _ cursor: HistoryCursor) {
    let key = prefix + deviceKey
    defaults.set(cursor.nextOffset, forKey: "\(key).offset")
    defaults.set(NSNumber(value: cursor.tailDeviceSeconds), forKey: "\(key).tail")
    defaults.set(NSNumber(value: cursor.newestDeviceSeconds), forKey: "\(key).newest")
    defaults.set(cursor.linked, forKey: "\(key).linked")
  }
}
