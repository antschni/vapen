import Foundation

/// InnoGate "CIG" framing (ELFA MASTER):
///
/// ```
/// [header][command][length u16 BE][payload…]
/// header = version << 6 | encrypted << 4 | seq & 0x0F   (version 0, never encrypted here)
/// ```
///
/// Responses echo the sequence nibble and set bit 7 of the command (`command | 0x80`).
enum InnogateFrameCodec {
  static let headerSize = 4

  static func encode(seq: Int, command: Int, payload: [UInt8] = []) -> [UInt8] {
    precondition(payload.count <= 0xFFFF, "payload too large")
    var out: [UInt8] = [
      UInt8(seq & 0x0F),
      UInt8(command & 0xFF),
      UInt8((payload.count >> 8) & 0xFF),
      UInt8(payload.count & 0xFF),
    ]
    out.append(contentsOf: payload)
    return out
  }

  static func decode(_ value: [UInt8]) -> CigFrame? {
    guard value.count >= headerSize else { return nil }
    let declared = (Int(value[2]) << 8) | Int(value[3])
    guard declared <= value.count - headerSize else { return nil }
    return CigFrame(
      header: Int(value[0]),
      command: Int(value[1]),
      payload: Array(value[headerSize..<(headerSize + declared)])
    )
  }
}

struct CigFrame {
  let header: Int
  let command: Int
  let payload: [UInt8]

  var seq: Int { header & 0x0F }
  var encrypted: Bool { header & 0x10 != 0 }
  var isResponse: Bool { command & BleConstants.responseFlag != 0 }

  func u8(_ index: Int) -> Int? {
    payload.indices.contains(index) ? Int(payload[index]) : nil
  }
}
