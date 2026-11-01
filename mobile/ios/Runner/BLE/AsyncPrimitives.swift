import Foundation

/// A value delivered at most once; `wait` returns nil on timeout or task cancellation.
/// Plays the role of Kotlin's `CompletableDeferred` + `withTimeoutOrNull`.
final class OneShot<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var done = false
  private var result: Value?
  private var waiter: CheckedContinuation<Value?, Never>?

  /// Returns false if a value (or timeout) was already delivered.
  @discardableResult
  func complete(_ value: Value?) -> Bool {
    lock.lock()
    if done {
      lock.unlock()
      return false
    }
    done = true
    result = value
    let continuation = waiter
    waiter = nil
    lock.unlock()
    continuation?.resume(returning: value)
    return true
  }

  func wait(timeoutMs: Int64) async -> Value? {
    await withTaskCancellationHandler {
      await withCheckedContinuation { (continuation: CheckedContinuation<Value?, Never>) in
        lock.lock()
        if done {
          let value = result
          lock.unlock()
          continuation.resume(returning: value)
          return
        }
        waiter = continuation
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(timeoutMs))) { [weak self] in
          self?.complete(nil)
        }
      }
    } onCancel: {
      self.complete(nil)
    }
  }
}

/// FIFO lock usable across `await`, like Kotlin's `Mutex`.
final class AsyncMutex: @unchecked Sendable {
  private let lock = NSLock()
  private var locked = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func withLock<T>(_ body: () async throws -> T) async rethrows -> T {
    await acquire()
    defer { release() }
    return try await body()
  }

  private func acquire() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      lock.lock()
      if locked {
        waiters.append(continuation)
        lock.unlock()
      } else {
        locked = true
        lock.unlock()
        continuation.resume()
      }
    }
  }

  private func release() {
    lock.lock()
    if waiters.isEmpty {
      locked = false
      lock.unlock()
    } else {
      let next = waiters.removeFirst()
      lock.unlock()
      next.resume()
    }
  }
}

func sleepMs(_ ms: Int64) async {
  try? await Task.sleep(nanoseconds: UInt64(max(ms, 0)) * 1_000_000)
}

func nowEpochMs() -> Int64 {
  Int64((Date().timeIntervalSince1970 * 1000).rounded(.down))
}

extension Date {
  init(epochMs: Int64) {
    self.init(timeIntervalSince1970: Double(epochMs) / 1000)
  }

  var epochMs: Int64 { Int64((timeIntervalSince1970 * 1000).rounded(.down)) }
}

extension Sequence where Element == UInt8 {
  var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
