import CoreBluetooth
import CryptoKit
import Foundation

/// ELFA MASTER over the InnoGate "CIG" channel. Protocol reference: docs/elfbar-protocol.md.
///
/// One request is in flight at a time; the response is the notification whose command is
/// `request | 0x80`. Every other notification is an unsolicited push.
final class ElfbarMasterProtocol: VapeProtocol, @unchecked Sendable {
  let model = "elfbar_master"

  private final class Pending {
    let responseCommand: Int
    let response = OneShot<CigFrame>()

    init(responseCommand: Int) {
      self.responseCommand = responseCommand
    }
  }

  private let identity: () -> ClientIdentity
  private let cursorStore: HistoryCursorStore
  private let clock: () -> Int64
  private let timeZone: () -> TimeZone

  private let requestMutex = AsyncMutex()
  private let syncMutex = AsyncMutex()

  /// Guards everything below; notifications arrive on the BLE queue while requests run in tasks.
  private let lock = NSLock()
  private var seq = 0
  private var pending: Pending?
  private var deviceKey = "default"
  private var mtu = ElfbarMasterProtocol.defaultMtu
  private var battery: Int?
  private var liquid: Int?
  private var childLock: Bool?
  private var firmware: String?
  private var lastFrameAt: Int64 = 0

  init(
    identity: @escaping () -> ClientIdentity = { ClientIdentity(name: "Vapen", id: "vapen") },
    cursorStore: HistoryCursorStore = InMemoryHistoryCursorStore(),
    clock: @escaping () -> Int64 = nowEpochMs,
    timeZone: @escaping () -> TimeZone = { TimeZone.current }
  ) {
    self.identity = identity
    self.cursorStore = cursorStore
    self.clock = clock
    self.timeZone = timeZone
  }

  var lastFrameAtMillis: Int64 { locked { lastFrameAt } }

  func matches(_ advertisement: Advertisement) -> Bool {
    guard let name = advertisement.name?.lowercased() else { return false }
    return BleConstants.nameHints.contains { name.contains($0) }
  }

  func bindDevice(_ deviceKey: String) {
    locked {
      if deviceKey != self.deviceKey {
        battery = nil
        liquid = nil
        childLock = nil
        firmware = nil
      }
      self.deviceKey = deviceKey
    }
  }

  func initialize(session: GattSession, profile: BleProfile) async throws -> [DeviceMessage] {
    locked { lastFrameAt = 0 }
    let negotiated = await session.requestMtu(BleConstants.mtuRequest)
    locked { mtu = negotiated }
    try await session.setNotify(service: profile.serviceUuid, characteristic: profile.rxUuid, enabled: true)
    if let ota = profile.otaNotify {
      try? await session.setNotify(service: ota.service, characteristic: ota.characteristic, enabled: true)
    }

    let key = locked { deviceKey }
    let cursor = cursorStore.load(key)
    let link = try await transact(
      session,
      profile,
      BleConstants.cmdFirstLinkInfo,
      Self.firstLinkPayload(identity()),
      timeoutMs: cursor.linked ? Self.reconnectLinkTimeoutMs : Self.firstLinkTimeoutMs
    )
    let linkResult = link.u8(0)
    if linkResult != 0 {
      throw ProtocolError(
        "Elfbar hat die Verbindung abgelehnt (Code \(linkResult.map(String.init) ?? "-")). "
          + "InnoGate schließen und Kopplung am Gerät bestätigen."
      )
    }
    if !cursor.linked {
      var linked = cursor
      linked.linked = true
      cursorStore.save(key, linked)
    }

    var messages: [DeviceMessage] = []
    let active = await transactOrNil(session, profile, BleConstants.cmdReadActiveState)?.u8(0)
    if active == 0 {
      messages.append(.warning("Elfbar ist nicht aktiviert — einmalig in der InnoGate-App aktivieren."))
    }
    if let frame = await transactOrNil(session, profile, BleConstants.cmdReadFirmwareVersion) {
      let text = String(decoding: frame.payload, as: UTF8.self)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\u{0}"..."\u{20}"))
      locked { firmware = text.isEmpty ? nil : text }
    }
    let timeSet = await transactOrNil(
      session,
      profile,
      BleConstants.cmdSetTime,
      Array(deviceClockString().utf8)
    )?.u8(0) == 0
    if !timeSet {
      messages.append(.warning("Uhrzeit der Elfbar konnte nicht gesetzt werden — Zeitstempel evtl. ungenau."))
    }
    return messages
  }

  func onNotification(characteristic: CBUUID, value: Data, receivedAtMillis: Int64) -> [DeviceMessage] {
    guard characteristic == BleConstants.cigNotify else { return [] }
    let bytes = [UInt8](value)
    guard let frame = InnogateFrameCodec.decode(bytes) else {
      return [.unknown(characteristic: characteristic, raw: bytes)]
    }
    let waiting: Pending? = locked {
      lastFrameAt = receivedAtMillis
      return pending
    }
    if let waiting, frame.command == waiting.responseCommand, waiting.response.complete(frame) {
      return []
    }
    return decodePush(frame, at: Date(epochMs: receivedAtMillis), characteristic: characteristic, raw: bytes)
  }

  func requestStatus(session: GattSession, profile: BleProfile) async -> [DeviceMessage] {
    if let value = await transactOrNil(session, profile, BleConstants.cmdReadSoc, [Self.unitPercent])?.u8(0),
       (0...100).contains(value) {
      locked { battery = value }
    }
    if let value = await transactOrNil(session, profile, BleConstants.cmdReadFuel, [Self.unitPercent])?.u8(0),
       (0...100).contains(value) {
      locked { liquid = value }
    }
    if let value = await transactOrNil(session, profile, BleConstants.cmdReadLockState)?.u8(0) {
      locked { childLock = value == 1 }
    }
    let now = Date(epochMs: clock())
    let today = await transactOrNil(session, profile, BleConstants.cmdReadDayPuff, [1])
      .flatMap { Self.parseTodayPuffs($0.payload) }
    var messages: [DeviceMessage] = [.status(statusSnapshot(at: now))]
    if let today { messages.append(.dailyPuffCount(today: today, at: now)) }
    return messages
  }

  func syncHistory(session: GattSession, profile: BleProfile) async -> [DeviceMessage] {
    await syncMutex.withLock { () async -> [DeviceMessage] in
      let (key, mtu) = locked { (deviceKey, self.mtu) }
      let cursor = cursorStore.load(key)
      let pageSize = min(
        max((mtu - Self.attOverhead - InnogateFrameCodec.headerSize - 2) / Self.puffRecordSize, 1),
        Self.maxPageSize
      )

      var offset = cursor.nextOffset
      var rescan = false
      if offset > 0 {
        guard let probe = await readPuffPage(session, profile, offset: offset - 1, count: 1) else { return [] }
        if probe.records.first?.deviceSeconds != cursor.tailDeviceSeconds {
          offset = 0
          rescan = true
        }
      }

      let nowMs = clock()
      var out: [DeviceMessage] = []
      var tail = cursor.tailDeviceSeconds
      var newest = cursor.newestDeviceSeconds
      var pages = 0
      var aborted = false
      while pages < Self.maxPages {
        guard let page = await readPuffPage(session, profile, offset: offset, count: pageSize) else {
          aborted = true
          break
        }
        pages += 1
        guard let first = page.records.first, let last = page.records.last else { break }
        var newInPage = 0
        for record in page.records {
          if !rescan || record.deviceSeconds > cursor.newestDeviceSeconds {
            if let message = toMessage(record, nowMs: nowMs) {
              out.append(message)
              newInPage += 1
            }
          }
          newest = max(newest, record.deviceSeconds)
        }
        offset += page.records.count
        tail = last.deviceSeconds
        if page.claimed < pageSize || page.records.count < page.claimed { break }
        let newestFirst = first.deviceSeconds > last.deviceSeconds
        if rescan && newestFirst && newInPage == 0 { break }
      }
      // An interrupted rescan must not advance `newest`: records it did not reach would be filtered
      // out forever. Keeping the old cursor rescans next time; event ids dedupe what was already sent.
      if !(rescan && aborted) {
        var next = cursor
        next.nextOffset = offset
        next.tailDeviceSeconds = tail
        next.newestDeviceSeconds = newest
        cursorStore.save(key, next)
      }
      return out
    }
  }

  func hardwareId(_ info: DeviceInfo) -> String {
    let source = info.serialNumber?.lowercased() ?? info.address.lowercased()
    return SHA256.hash(data: Data(source.utf8)).hexString
  }

  // MARK: - Requests

  private func transact(
    _ session: GattSession,
    _ profile: BleProfile,
    _ command: Int,
    _ payload: [UInt8] = [],
    timeoutMs: Int64 = ElfbarMasterProtocol.defaultTimeoutMs
  ) async throws -> CigFrame {
    try await requestMutex.withLock { () async throws -> CigFrame in
      let waiting = Pending(responseCommand: command | BleConstants.responseFlag)
      let frameSeq: Int = locked {
        let current = seq
        seq = (seq + 1) & 0x0F
        pending = waiting
        return current
      }
      defer {
        locked {
          if pending === waiting { pending = nil }
        }
      }
      try await session.write(
        service: profile.serviceUuid,
        characteristic: profile.txUuid,
        value: Data(InnogateFrameCodec.encode(seq: frameSeq, command: command, payload: payload)),
        withResponse: true
      )
      guard let frame = await waiting.response.wait(timeoutMs: timeoutMs) else {
        throw ProtocolError(String(format: "Keine Antwort der Elfbar auf Befehl 0x%02X", UInt32(command & 0xFF)))
      }
      return frame
    }
  }

  private func transactOrNil(
    _ session: GattSession,
    _ profile: BleProfile,
    _ command: Int,
    _ payload: [UInt8] = []
  ) async -> CigFrame? {
    try? await transact(session, profile, command, payload)
  }

  private func readPuffPage(_ session: GattSession, _ profile: BleProfile, offset: Int, count: Int) async -> PuffPage? {
    let request: [UInt8] = [
      UInt8((offset >> 8) & 0xFF),
      UInt8(offset & 0xFF),
      UInt8((count >> 8) & 0xFF),
      UInt8(count & 0xFF),
    ]
    guard let frame = await transactOrNil(session, profile, BleConstants.cmdReadPuffRecords, request) else {
      return nil
    }
    return Self.parsePuffPage(frame.payload)
  }

  // MARK: - Decoding

  private func decodePush(_ frame: CigFrame, at: Date, characteristic: CBUUID, raw: [UInt8]) -> [DeviceMessage] {
    switch frame.command {
    case BleConstants.cmdReadSoc | BleConstants.responseFlag:
      guard let value = frame.u8(0), (0...100).contains(value) else { return [] }
      locked { battery = value }
      return [.status(statusSnapshot(at: at))]
    case BleConstants.cmdReadFuel | BleConstants.responseFlag:
      guard let value = frame.u8(0), (0...100).contains(value) else { return [] }
      locked { liquid = value }
      return [.status(statusSnapshot(at: at))]
    case BleConstants.cmdReadLockState | BleConstants.responseFlag:
      guard let value = frame.u8(0) else { return [] }
      locked { childLock = value == 1 }
      return [.status(statusSnapshot(at: at))]
    case BleConstants.cmdReadSuctionTime | BleConstants.responseFlag:
      guard let tenths = frame.u8(0) else { return [] }
      return tenths == 0 ? [] : [.puffDetected(at: at, durationMs: tenths * 100)]
    case BleConstants.cmdReadDayPuff | BleConstants.responseFlag:
      guard let today = Self.parseTodayPuffs(frame.payload) else { return [] }
      return [.dailyPuffCount(today: today, at: at)]
    case BleConstants.pushDeviceReport:
      guard let code = frame.u8(0) else { return [] }
      return [.deviceAlert(code: code, at: at)]
    default:
      return [.unknown(characteristic: characteristic, raw: raw)]
    }
  }

  private func statusSnapshot(at: Date) -> DeviceStatus {
    locked {
      DeviceStatus(
        battery: battery,
        charging: nil,
        liquid: liquid,
        counterTotal: nil,
        powerMode: nil,
        childLock: childLock,
        firmware: firmware,
        recordedAt: at
      )
    }
  }

  private func toMessage(_ record: PuffRecord, nowMs: Int64) -> DeviceMessage? {
    guard (1...Self.maxPuffMs).contains(record.durationMs) else { return nil }
    var startMs = nowMs - Int64(record.durationMs)
    if let deviceMs = deviceSecondsToEpochMs(record.deviceSeconds),
       (Self.minPlausibleMs...(nowMs + Self.clockSkewMs)).contains(deviceMs) {
      startMs = deviceMs
    }
    let startedAt = Date(epochMs: startMs)
    if nowMs - startMs <= Self.liveWindowMs {
      return .puffCompleted(startedAt: startedAt, durationMs: record.durationMs, deviceIndex: record.deviceSeconds, raw: record.raw)
    }
    return .historyPuff(startedAt: startedAt, durationMs: record.durationMs, deviceIndex: record.deviceSeconds, raw: record.raw)
  }

  /// The device counts local wall-clock seconds as if they were UTC.
  private func deviceSecondsToEpochMs(_ deviceSeconds: Int64) -> Int64? {
    guard deviceSeconds > 0 else { return nil }
    let tz = timeZone()
    let local = Double(deviceSeconds)
    let guess = tz.secondsFromGMT(for: Date(timeIntervalSince1970: local))
    let offset = tz.secondsFromGMT(for: Date(timeIntervalSince1970: local - Double(guess)))
    return (deviceSeconds - Int64(offset)) * 1000
  }

  private func deviceClockString() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone()
    formatter.dateFormat = "yyyyMMddHHmmss"
    return formatter.string(from: Date(epochMs: clock()))
  }

  private func locked<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  // MARK: - Constants and pure parsers

  private static let defaultMtu = 23
  private static let attOverhead = 3
  static let puffRecordSize = 8
  private static let maxPageSize = 10
  private static let maxPages = 400
  private static let unitPercent: UInt8 = 0
  private static let defaultTimeoutMs: Int64 = 5_000
  private static let firstLinkTimeoutMs: Int64 = 60_000
  private static let reconnectLinkTimeoutMs: Int64 = 10_000
  private static let maxPuffMs = 60_000
  private static let liveWindowMs: Int64 = 10 * 60_000
  private static let clockSkewMs: Int64 = 24 * 3_600_000
  private static let minPlausibleMs: Int64 = 1_672_531_200_000 // 2023-01-01T00:00:00Z
  private static let maxNameBytes = 32

  static func firstLinkPayload(_ identity: ClientIdentity) -> [UInt8] {
    let name = utf8Truncated(identity.name.isBlank ? "Vapen" : identity.name, maxBytes: maxNameBytes)
    let id = utf8Truncated(identity.id.isBlank ? "vapen" : identity.id, maxBytes: 64)
    return [UInt8(BleConstants.identifierTypeAndroid), UInt8(name.count)] + name + [UInt8(id.count)] + id
  }

  private static func utf8Truncated(_ value: String, maxBytes: Int) -> [UInt8] {
    var text = Substring(value)
    while !text.isEmpty {
      let bytes = Array(text.utf8)
      if bytes.count <= maxBytes { return bytes }
      text = text.dropLast()
    }
    return []
  }

  /// Response payload of READ_DAY_PUFF: `[days][u16 BE per day…]`, today first.
  static func parseTodayPuffs(_ payload: [UInt8]) -> Int? {
    guard let days = payload.first, days >= 1, payload.count >= 3 else { return nil }
    return (Int(payload[1]) << 8) | Int(payload[2])
  }

  /// Response payload of READ_PUFF_RECORDS: `[count u16 BE]` then `count` records of 8 bytes:
  /// `[power ×0.1 W][duration u16 LE ×10 ms][resistance ×0.1 Ω][device seconds u32 LE]`.
  static func parsePuffPage(_ payload: [UInt8]) -> PuffPage? {
    guard payload.count >= 2 else { return nil }
    let claimed = (Int(payload[0]) << 8) | Int(payload[1])
    var records: [PuffRecord] = []
    for i in 0..<claimed {
      let base = 2 + i * puffRecordSize
      if base + puffRecordSize > payload.count { break }
      let duration = (Int(payload[base + 1]) | (Int(payload[base + 2]) << 8)) * 10
      let seconds = Int64(payload[base + 4])
        | (Int64(payload[base + 5]) << 8)
        | (Int64(payload[base + 6]) << 16)
        | (Int64(payload[base + 7]) << 24)
      records.append(
        PuffRecord(
          deviceSeconds: seconds,
          durationMs: duration,
          powerWatts: Double(payload[base]) / 10,
          resistanceOhm: Double(payload[base + 3]) / 10,
          raw: Array(payload[base..<(base + puffRecordSize)])
        )
      )
    }
    return PuffPage(claimed: claimed, records: records)
  }
}

struct PuffRecord {
  let deviceSeconds: Int64
  let durationMs: Int
  let powerWatts: Double
  let resistanceOhm: Double
  let raw: [UInt8]
}

struct PuffPage {
  let claimed: Int
  let records: [PuffRecord]
}

extension String {
  var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
