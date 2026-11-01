import CoreBluetooth
import XCTest

@testable import Runner

/// Port of the Android `ElfbarMasterProtocolTest`; both implementations must behave identically.
final class ElfbarMasterProtocolTests: XCTestCase {
  private let profile = BleProfile(
    name: "innogate_cig",
    serviceUuid: BleConstants.cigService,
    txUuid: BleConstants.cigWrite,
    rxUuid: BleConstants.cigNotify
  )
  private let berlin = TimeZone(identifier: "Europe/Berlin")!
  private let now = Date(timeIntervalSince1970: 1_791_136_800) // 2026-10-04T18:00:00Z
  private let deviceKey = "AA:BB:CC:DD:EE:FF"

  /// Device seconds as the firmware stores them: local wall clock encoded as if it were UTC.
  private func deviceSeconds(_ local: String) -> Int64 {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return Int64(formatter.date(from: local)!.timeIntervalSince1970)
  }

  private func instant(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
  }

  private struct Record {
    let seconds: Int64
    let durationMs: Int
  }

  private final class FakeElfa: GattSession {
    weak var protocolImpl: ElfbarMasterProtocol?
    var linkResult: UInt8 = 0
    var requests: [CigFrame] = []
    var records: [Record] = []
    var battery: UInt8 = 64
    var liquid: UInt8 = 35
    var today = 12

    func read(service: CBUUID, characteristic: CBUUID) async -> Data? { nil }
    func setNotify(service: CBUUID, characteristic: CBUUID, enabled: Bool) async throws {}
    func requestMtu(_ mtu: Int) async -> Int { 247 }

    func write(service: CBUUID, characteristic: CBUUID, value: Data, withResponse: Bool) async throws {
      let request = InnogateFrameCodec.decode([UInt8](value))!
      requests.append(request)
      let payload: [UInt8]
      switch request.command {
      case BleConstants.cmdFirstLinkInfo: payload = [linkResult]
      case BleConstants.cmdReadActiveState: payload = [1]
      case BleConstants.cmdReadFirmwareVersion: payload = Array("V1.0.7".utf8)
      case BleConstants.cmdSetTime: payload = [0]
      case BleConstants.cmdReadSoc: payload = [battery]
      case BleConstants.cmdReadFuel: payload = [liquid]
      case BleConstants.cmdReadLockState: payload = [0]
      case BleConstants.cmdReadDayPuff: payload = [1, UInt8((today >> 8) & 0xFF), UInt8(today & 0xFF)]
      case BleConstants.cmdReadPuffRecords: payload = puffPage(request.payload)
      default: return
      }
      let response = InnogateFrameCodec.encode(seq: request.seq, command: request.command | 0x80, payload: payload)
      _ = protocolImpl?.onNotification(characteristic: BleConstants.cigNotify, value: Data(response), receivedAtMillis: 0)
    }

    private func puffPage(_ request: [UInt8]) -> [UInt8] {
      let offset = (Int(request[0]) << 8) | Int(request[1])
      let count = (Int(request[2]) << 8) | Int(request[3])
      let page = Array(records.dropFirst(offset).prefix(count))
      var out: [UInt8] = [UInt8((page.count >> 8) & 0xFF), UInt8(page.count & 0xFF)]
      for record in page {
        let tens = record.durationMs / 10
        out += [120, UInt8(tens & 0xFF), UInt8((tens >> 8) & 0xFF), 8]
        for b in 0..<4 { out.append(UInt8((record.seconds >> (8 * Int64(b))) & 0xFF)) }
      }
      return out
    }
  }

  private func setup(
    _ device: FakeElfa = FakeElfa(),
    store: HistoryCursorStore = InMemoryHistoryCursorStore()
  ) -> ElfbarMasterProtocol {
    let fixedNow = now
    let berlin = self.berlin
    let protocolImpl = ElfbarMasterProtocol(
      identity: { ClientIdentity(name: "Pixel von Anton", id: "a1b2c3d4e5f60718") },
      cursorStore: store,
      clock: { fixedNow.epochMs },
      timeZone: { berlin }
    )
    device.protocolImpl = protocolImpl
    protocolImpl.bindDevice(deviceKey)
    return protocolImpl
  }

  private func durations(_ messages: [DeviceMessage]) -> [Int] {
    messages.compactMap {
      if case let .historyPuff(_, durationMs, _, _) = $0 { return durationMs }
      return nil
    }
  }

  func testInitializeRunsInnoGateHandshakeInOrder() async throws {
    let device = FakeElfa()
    let protocolImpl = setup(device)

    let messages = try await protocolImpl.initialize(session: device, profile: profile)

    XCTAssertEqual(
      device.requests.map(\.command),
      [
        BleConstants.cmdFirstLinkInfo,
        BleConstants.cmdReadActiveState,
        BleConstants.cmdReadFirmwareVersion,
        BleConstants.cmdSetTime,
      ]
    )
    XCTAssertTrue(messages.isEmpty)

    let link = device.requests[0].payload
    XCTAssertEqual(Int(link[0]), BleConstants.identifierTypeAndroid)
    let nameLength = Int(link[1])
    XCTAssertEqual(String(decoding: link[2..<(2 + nameLength)], as: UTF8.self), "Pixel von Anton")
    let idLength = Int(link[2 + nameLength])
    XCTAssertEqual(
      String(decoding: link[(3 + nameLength)..<(3 + nameLength + idLength)], as: UTF8.self),
      "a1b2c3d4e5f60718"
    )

    XCTAssertEqual(String(decoding: device.requests[3].payload, as: UTF8.self), "20261004200000")
    XCTAssertEqual(device.requests.map(\.seq), device.requests.indices.map { $0 & 0x0F })
  }

  func testInitializeFailsWhenDeviceRejectsLink() async {
    let device = FakeElfa()
    device.linkResult = 1
    let protocolImpl = setup(device)
    do {
      _ = try await protocolImpl.initialize(session: device, profile: profile)
      XCTFail("expected ProtocolError")
    } catch let error as ProtocolError {
      XCTAssertTrue(error.message.contains("abgelehnt"))
    } catch {
      XCTFail("unexpected error \(error)")
    }
  }

  func testRequestStatusReadsBatteryLiquidAndTodayCount() async throws {
    let device = FakeElfa()
    let protocolImpl = setup(device)
    _ = try await protocolImpl.initialize(session: device, profile: profile)

    let messages = await protocolImpl.requestStatus(session: device, profile: profile)

    let statuses = messages.compactMap { message -> DeviceStatus? in
      if case let .status(status) = message { return status }
      return nil
    }
    XCTAssertEqual(statuses.count, 1)
    XCTAssertEqual(statuses[0].battery, 64)
    XCTAssertEqual(statuses[0].liquid, 35)
    XCTAssertEqual(statuses[0].childLock, false)
    XCTAssertEqual(statuses[0].firmware, "V1.0.7")
    let today = messages.compactMap { message -> Int? in
      if case let .dailyPuffCount(today, _) = message { return today }
      return nil
    }
    XCTAssertEqual(today, [12])
  }

  func testSyncHistoryPagesThroughRecordsAndResumesFromCursor() async {
    let device = FakeElfa()
    let store = InMemoryHistoryCursorStore()
    let protocolImpl = setup(device, store: store)
    let base = deviceSeconds("2026-10-04T08:00:00")
    for i in 0..<13 { device.records.append(Record(seconds: base + Int64(i) * 600, durationMs: 1500 + i * 10)) }

    let first = await protocolImpl.syncHistory(session: device, profile: profile)

    XCTAssertEqual(first.count, 13)
    guard case let .historyPuff(startedAt, durationMs, deviceIndex, _) = first[0] else {
      return XCTFail("expected history puff, got \(first[0])")
    }
    XCTAssertEqual(startedAt, instant("2026-10-04T06:00:00Z"))
    XCTAssertEqual(durationMs, 1500)
    XCTAssertEqual(deviceIndex, base)
    XCTAssertEqual(store.load(deviceKey).nextOffset, 13)

    let second = await protocolImpl.syncHistory(session: device, profile: profile)
    XCTAssertTrue(second.isEmpty)

    device.records.append(Record(seconds: deviceSeconds("2026-10-04T19:58:00"), durationMs: 2340))
    let third = await protocolImpl.syncHistory(session: device, profile: profile)
    XCTAssertEqual(third.count, 1)
    guard case let .puffCompleted(liveStart, liveDuration, _, _) = third[0] else {
      return XCTFail("expected live puff, got \(third[0])")
    }
    XCTAssertEqual(liveStart, instant("2026-10-04T17:58:00Z"))
    XCTAssertEqual(liveDuration, 2340)
  }

  func testSyncHistoryRescansWhenDeviceListWasCleared() async {
    let device = FakeElfa()
    let protocolImpl = setup(device)
    let base = deviceSeconds("2026-10-04T08:00:00")
    for i in 0..<5 { device.records.append(Record(seconds: base + Int64(i) * 60, durationMs: 1200)) }
    let initial = await protocolImpl.syncHistory(session: device, profile: profile)
    XCTAssertEqual(initial.count, 5)

    device.records = [
      Record(seconds: base + 3_600, durationMs: 1800),
      Record(seconds: base + 3_660, durationMs: 1900),
    ]

    let after = await protocolImpl.syncHistory(session: device, profile: profile)
    XCTAssertEqual(durations(after), [1800, 1900])
  }

  func testSyncHistoryDoesNotReemitAfterRescanOfUnchangedNewestFirstList() async {
    let device = FakeElfa()
    let protocolImpl = setup(device)
    let base = deviceSeconds("2026-10-04T08:00:00")
    for i in 0..<25 { device.records.append(Record(seconds: base + Int64(25 - i) * 60, durationMs: 1300)) }
    let initial = await protocolImpl.syncHistory(session: device, profile: profile)
    XCTAssertEqual(initial.count, 25)

    device.records.insert(Record(seconds: base + 26 * 60, durationMs: 2100), at: 0)
    let after = await protocolImpl.syncHistory(session: device, profile: profile)
    XCTAssertEqual(durations(after), [2100])
  }

  func testPushesAreDecoded() {
    let protocolImpl = setup()
    func push(_ command: Int, _ payload: UInt8...) -> [DeviceMessage] {
      protocolImpl.onNotification(
        characteristic: BleConstants.cigNotify,
        value: Data(InnogateFrameCodec.encode(seq: 0, command: command, payload: payload)),
        receivedAtMillis: now.epochMs
      )
    }

    let detected = push(0x96, 23)
    guard detected.count == 1, case let .puffDetected(_, durationMs) = detected[0] else {
      return XCTFail("expected puff detected, got \(detected)")
    }
    XCTAssertEqual(durationMs, 2300)

    let battery = push(0x92, 81)
    guard battery.count == 1, case let .status(status) = battery[0] else {
      return XCTFail("expected status, got \(battery)")
    }
    XCTAssertEqual(status.battery, 81)

    let daily = push(0xC1, 1, 0, 40)
    guard daily.count == 1, case let .dailyPuffCount(today, _) = daily[0] else {
      return XCTFail("expected daily count, got \(daily)")
    }
    XCTAssertEqual(today, 40)

    let alert = push(0x9E, 2)
    guard alert.count == 1, case let .deviceAlert(code, _) = alert[0] else {
      return XCTFail("expected alert, got \(alert)")
    }
    XCTAssertEqual(code, 2)

    XCTAssertTrue(push(0x93, 255).isEmpty)
    XCTAssertTrue(push(0x96, 0).isEmpty)
  }

  func testNotificationsOnOtherCharacteristicsAreIgnored() {
    let protocolImpl = setup()
    let frame = Data(InnogateFrameCodec.encode(seq: 0, command: 0x92, payload: [50]))
    XCTAssertTrue(protocolImpl.onNotification(characteristic: BleConstants.otaNotify, value: frame, receivedAtMillis: 0).isEmpty)
  }
}
