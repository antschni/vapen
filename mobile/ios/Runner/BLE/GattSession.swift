import CoreBluetooth

struct GattError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

/// Abstraction over CoreBluetooth GATT for protocol tests.
protocol GattSession: AnyObject {
  func read(service: CBUUID, characteristic: CBUUID) async -> Data?
  func write(service: CBUUID, characteristic: CBUUID, value: Data, withResponse: Bool) async throws
  func setNotify(service: CBUUID, characteristic: CBUUID, enabled: Bool) async throws
  /// iOS negotiates the MTU on its own; returns the effective ATT MTU.
  func requestMtu(_ mtu: Int) async -> Int
}

/// Serializes GATT operations and pairs them with their delegate callbacks.
final class GattOperationQueue: @unchecked Sendable {
  private static let timeoutMs: Int64 = 10_000

  private let mutex = AsyncMutex()
  private let lock = NSLock()
  private var pendingRead: (characteristic: CBUUID, result: OneShot<Data>)?
  private var pendingWrite: OneShot<Bool>?
  private var pendingNotify: OneShot<Bool>?

  func read(_ characteristic: CBUUID, start: @escaping () -> Bool) async -> Data? {
    await mutex.withLock { () async -> Data? in
      let op = OneShot<Data>()
      locked { pendingRead = (characteristic, op) }
      defer { locked { pendingRead = nil } }
      guard start() else { return nil }
      return await op.wait(timeoutMs: Self.timeoutMs)
    }
  }

  func write(start: @escaping () -> Bool) async -> Bool {
    await mutex.withLock { () async -> Bool in
      let op = OneShot<Bool>()
      locked { pendingWrite = op }
      defer { locked { pendingWrite = nil } }
      guard start() else { return false }
      return await op.wait(timeoutMs: Self.timeoutMs) ?? false
    }
  }

  func notify(start: @escaping () -> Bool) async -> Bool {
    await mutex.withLock { () async -> Bool in
      let op = OneShot<Bool>()
      locked { pendingNotify = op }
      defer { locked { pendingNotify = nil } }
      guard start() else { return false }
      return await op.wait(timeoutMs: Self.timeoutMs) ?? false
    }
  }

  /// Returns false when no read was pending for `characteristic` (then the value is a notification).
  func completeRead(_ characteristic: CBUUID, success: Bool, data: Data?) -> Bool {
    guard let pending = locked({ pendingRead }), pending.characteristic == characteristic else { return false }
    return pending.result.complete(success ? data : nil)
  }

  func completeWrite(_ success: Bool) {
    locked { pendingWrite }?.complete(success)
  }

  func completeNotify(_ success: Bool) {
    locked { pendingNotify }?.complete(success)
  }

  /// Fails whatever is in flight, e.g. after the link dropped.
  func failAll() {
    let (read, write, notify) = locked { (pendingRead, pendingWrite, pendingNotify) }
    read?.result.complete(nil)
    write?.complete(false)
    notify?.complete(false)
  }

  private func locked<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }
}

/// CoreBluetooth calls are issued on the manager's queue; completions come from its delegate.
final class CoreBluetoothGattSession: GattSession {
  private weak var peripheral: CBPeripheral?
  private let queue: DispatchQueue
  private let ops: GattOperationQueue

  init(peripheral: CBPeripheral, queue: DispatchQueue, ops: GattOperationQueue) {
    self.peripheral = peripheral
    self.queue = queue
    self.ops = ops
  }

  func read(service: CBUUID, characteristic: CBUUID) async -> Data? {
    await ops.read(characteristic) { [self] in
      queue.sync { () -> Bool in
        guard let p = peripheral, p.state == .connected,
              let c = Self.characteristic(p, service, characteristic) else { return false }
        p.readValue(for: c)
        return true
      }
    }
  }

  func write(service: CBUUID, characteristic: CBUUID, value: Data, withResponse: Bool) async throws {
    if !withResponse {
      let sent: Bool = queue.sync {
        guard let p = peripheral, p.state == .connected,
              let c = Self.characteristic(p, service, characteristic) else { return false }
        p.writeValue(value, for: c, type: .withoutResponse)
        return true
      }
      if !sent { throw GattError(message: "Schreiben auf \(characteristic) fehlgeschlagen") }
      return
    }
    let ok = await ops.write { [self] in
      queue.sync { () -> Bool in
        guard let p = peripheral, p.state == .connected,
              let c = Self.characteristic(p, service, characteristic) else { return false }
        p.writeValue(value, for: c, type: .withResponse)
        return true
      }
    }
    if !ok { throw GattError(message: "Schreiben auf \(characteristic) fehlgeschlagen") }
  }

  func setNotify(service: CBUUID, characteristic: CBUUID, enabled: Bool) async throws {
    let ok = await ops.notify { [self] in
      queue.sync { () -> Bool in
        guard let p = peripheral, p.state == .connected,
              let c = Self.characteristic(p, service, characteristic),
              !c.properties.isDisjoint(with: [.notify, .indicate]) else { return false }
        p.setNotifyValue(enabled, for: c)
        return true
      }
    }
    if !ok { throw GattError(message: "Notifications auf \(characteristic) konnten nicht aktiviert werden") }
  }

  func requestMtu(_ mtu: Int) async -> Int {
    queue.sync { () -> Int in
      guard let p = peripheral else { return 23 }
      return min(p.maximumWriteValueLength(for: .withoutResponse) + 3, mtu)
    }
  }

  private static func characteristic(_ p: CBPeripheral, _ service: CBUUID, _ characteristic: CBUUID) -> CBCharacteristic? {
    p.services?.first(where: { $0.uuid == service })?
      .characteristics?.first(where: { $0.uuid == characteristic })
  }
}
