import XCTest

@testable import Runner

final class InnogateFrameCodecTests: XCTestCase {
  func testEncodeWithoutPayloadMatchesInnoGateLayout() {
    XCTAssertEqual(InnogateFrameCodec.encode(seq: 3, command: 0x05), [0x03, 0x05, 0x00, 0x00])
  }

  func testEncodeLengthIsBigEndianAndSeqIsMasked() {
    let payload = (0..<0x0102).map { UInt8(truncatingIfNeeded: $0) }
    let frame = InnogateFrameCodec.encode(seq: 0x1F, command: 0x33, payload: payload)
    XCTAssertEqual(frame[0], 0x0F)
    XCTAssertEqual(frame[1], 0x33)
    XCTAssertEqual(frame[2], 0x01)
    XCTAssertEqual(frame[3], 0x02)
    XCTAssertEqual(frame.count, 4 + payload.count)
  }

  func testDecodeRoundTrip() throws {
    let encoded = InnogateFrameCodec.encode(seq: 7, command: 0x92, payload: [76])
    let frame = try XCTUnwrap(InnogateFrameCodec.decode(encoded))
    XCTAssertEqual(frame.seq, 7)
    XCTAssertEqual(frame.command, 0x92)
    XCTAssertTrue(frame.isResponse)
    XCTAssertFalse(frame.encrypted)
    XCTAssertEqual(frame.u8(0), 76)
  }

  func testDecodeRejectsTruncatedFrames() {
    XCTAssertNil(InnogateFrameCodec.decode([0x00, 0x92, 0x00]))
    XCTAssertNil(InnogateFrameCodec.decode([0x00, 0x92, 0x00, 0x02, 0x01]))
  }

  func testDecodeIgnoresTrailingBytes() throws {
    let frame = try XCTUnwrap(InnogateFrameCodec.decode([0x00, 0x92, 0x00, 0x01, 0x50, 0x7F]))
    XCTAssertEqual(frame.payload, [0x50])
  }
}

final class EventIdFactoryTests: XCTestCase {
  func testPuffIdIsDeterministicForDeviceIndex() {
    let a = EventIdFactory.puffId(hardwareId: "abc", deviceIndex: 42, startedAt: Date(timeIntervalSince1970: 1_791_021_600))
    let b = EventIdFactory.puffId(hardwareId: "abc", deviceIndex: 42, startedAt: Date(timeIntervalSince1970: 1_791_025_200))
    XCTAssertEqual(a, b)
  }

  func testUuidV5MatchesReferenceVector() {
    // RFC 4122 appendix-style vector: uuid5(NAMESPACE_DNS, "python.org"), as produced by Python and Java.
    XCTAssertEqual(EventIdFactory.uuidV5("python.org"), "886313e1-3b8a-5372-9b90-0c9aee199e5d")
  }
}
