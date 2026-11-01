import Foundation
import SQLite3

struct PendingEvent: Equatable {
  let clientEventId: String
  let type: String
  let payloadJson: String
  let createdAtEpochMs: Int64
}

struct DeadEvent: Equatable {
  let clientEventId: String
  let type: String
  let payloadJson: String
  let reason: String
  let createdAtEpochMs: Int64
}

/// Durable upload queue (SQLite), the counterpart of the Android Room tables. Thread-safe.
final class PendingEventStore: @unchecked Sendable {
  static let shared = PendingEventStore(url: PendingEventStore.defaultURL())

  private let lock = NSLock()
  private var db: OpaquePointer?

  init(url: URL) {
    if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
      NSLog("Vapen: opening event store failed: %@", String(cString: sqlite3_errmsg(db)))
    }
    exec("""
      CREATE TABLE IF NOT EXISTS pending_events (
        client_event_id TEXT PRIMARY KEY NOT NULL,
        type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at_epoch_ms INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
      """)
    exec("CREATE INDEX IF NOT EXISTS pending_events_created ON pending_events(created_at_epoch_ms)")
    exec("""
      CREATE TABLE IF NOT EXISTS dead_events (
        client_event_id TEXT PRIMARY KEY NOT NULL,
        type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at_epoch_ms INTEGER NOT NULL
      )
      """)
  }

  deinit {
    sqlite3_close(db)
  }

  /// Ignores duplicates: the deterministic client_event_id already identifies the event.
  func insert(_ event: PendingEvent) {
    run(
      "INSERT OR IGNORE INTO pending_events (client_event_id, type, payload_json, created_at_epoch_ms) VALUES (?, ?, ?, ?)",
      [.text(event.clientEventId), .text(event.type), .text(event.payloadJson), .int(event.createdAtEpochMs)]
    )
  }

  func insertDead(_ event: DeadEvent) {
    run(
      "INSERT OR REPLACE INTO dead_events (client_event_id, type, payload_json, reason, created_at_epoch_ms) VALUES (?, ?, ?, ?, ?)",
      [.text(event.clientEventId), .text(event.type), .text(event.payloadJson), .text(event.reason), .int(event.createdAtEpochMs)]
    )
  }

  func oldest(_ limit: Int) -> [PendingEvent] {
    query(
      "SELECT client_event_id, type, payload_json, created_at_epoch_ms FROM pending_events ORDER BY created_at_epoch_ms ASC LIMIT ?",
      [.int(Int64(limit))]
    ) { row in
      PendingEvent(
        clientEventId: Self.text(row, 0),
        type: Self.text(row, 1),
        payloadJson: Self.text(row, 2),
        createdAtEpochMs: sqlite3_column_int64(row, 3)
      )
    }
  }

  func deleteByIds(_ ids: [String]) {
    guard !ids.isEmpty else { return }
    lock.lock()
    defer { lock.unlock() }
    exec("BEGIN")
    for id in ids {
      runLocked("DELETE FROM pending_events WHERE client_event_id = ?", [.text(id)])
    }
    exec("COMMIT")
  }

  func count() -> Int {
    query("SELECT COUNT(*) FROM pending_events", []) { row in Int(sqlite3_column_int64(row, 0)) }.first ?? 0
  }

  // MARK: - SQLite plumbing

  private enum Value {
    case text(String)
    case int(Int64)
  }

  /// SQLite copies bound text immediately (the C macro is not visible to Swift).
  private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  private func exec(_ sql: String) {
    if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
      NSLog("Vapen: SQL failed (%@): %@", sql, String(cString: sqlite3_errmsg(db)))
    }
  }

  private func run(_ sql: String, _ values: [Value]) {
    lock.lock()
    defer { lock.unlock() }
    runLocked(sql, values)
  }

  private func runLocked(_ sql: String, _ values: [Value]) {
    guard let statement = prepare(sql, values) else { return }
    defer { sqlite3_finalize(statement) }
    if sqlite3_step(statement) != SQLITE_DONE {
      NSLog("Vapen: SQL failed (%@): %@", sql, String(cString: sqlite3_errmsg(db)))
    }
  }

  private func query<T>(_ sql: String, _ values: [Value], _ map: (OpaquePointer) -> T) -> [T] {
    lock.lock()
    defer { lock.unlock() }
    guard let statement = prepare(sql, values) else { return [] }
    defer { sqlite3_finalize(statement) }
    var rows: [T] = []
    while sqlite3_step(statement) == SQLITE_ROW {
      rows.append(map(statement))
    }
    return rows
  }

  private func prepare(_ sql: String, _ values: [Value]) -> OpaquePointer? {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      NSLog("Vapen: SQL prepare failed (%@): %@", sql, String(cString: sqlite3_errmsg(db)))
      return nil
    }
    for (index, value) in values.enumerated() {
      let position = Int32(index + 1)
      switch value {
      case .text(let text):
        sqlite3_bind_text(statement, position, text, -1, Self.transient)
      case .int(let number):
        sqlite3_bind_int64(statement, position, number)
      }
    }
    return statement
  }

  private static func text(_ row: OpaquePointer, _ column: Int32) -> String {
    guard let pointer = sqlite3_column_text(row, column) else { return "" }
    return String(cString: pointer)
  }

  private static func defaultURL() -> URL {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("vapen.sqlite")
  }
}
