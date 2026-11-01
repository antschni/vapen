import CoreBluetooth
import CryptoKit
import Foundation

final class SimulatedProtocol: VapeProtocol {
  let model = "elfbar_master"
  let lastFrameAtMillis: Int64 = 0

  private var puffIndex: Int64 = 0
  private var battery = 78
  private var liquid = 42

  func matches(_ advertisement: Advertisement) -> Bool { true }

  func bindDevice(_ deviceKey: String) {}

  func initialize(session: GattSession, profile: BleProfile) async throws -> [DeviceMessage] {
    await sleepMs(300)
    return []
  }

  func onNotification(characteristic: CBUUID, value: Data, receivedAtMillis: Int64) -> [DeviceMessage] { [] }

  func requestStatus(session: GattSession, profile: BleProfile) async -> [DeviceMessage] { [] }

  func syncHistory(session: GattSession, profile: BleProfile) async -> [DeviceMessage] { [] }

  func nextSimulatedPuff() -> DeviceMessage {
    puffIndex += 1
    let duration = Int.random(in: 1200..<4500)
    let started = Date().addingTimeInterval(-Double(duration) / 1000)
    return .puffCompleted(
      startedAt: started,
      durationMs: duration,
      deviceIndex: Int64(started.timeIntervalSince1970.rounded(.down)),
      raw: [0xA5, UInt8(truncatingIfNeeded: duration)]
    )
  }

  func nextSimulatedStatus() -> DeviceMessage {
    battery = min(max(battery - Int.random(in: 0..<2), 10), 100)
    liquid = min(max(liquid - Int.random(in: 0..<1), 5), 100)
    return .status(
      DeviceStatus(
        battery: battery,
        charging: false,
        liquid: liquid,
        counterTotal: puffIndex,
        powerMode: "normal",
        childLock: false,
        firmware: "sim-1.0.0",
        recordedAt: Date()
      )
    )
  }

  func hardwareId(_ info: DeviceInfo) -> String {
    let source = "simulated-\(info.address.lowercased())"
    return SHA256.hash(data: Data(source.utf8)).hexString
  }
}
