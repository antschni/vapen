import UIKit

/// Asks iOS for extra execution time while the app is in the background (BLE wake-ups only grant
/// a few seconds). Both UIKit calls used here are documented as safe off the main thread.
final class BackgroundActivity {
  private let lock = NSLock()
  private var identifier: UIBackgroundTaskIdentifier = .invalid

  static func begin(_ name: String) -> BackgroundActivity {
    let activity = BackgroundActivity()
    let identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak activity] in
      activity?.end()
    }
    activity.lock.lock()
    activity.identifier = identifier
    activity.lock.unlock()
    return activity
  }

  func end() {
    lock.lock()
    let current = identifier
    identifier = .invalid
    lock.unlock()
    if current != .invalid {
      UIApplication.shared.endBackgroundTask(current)
    }
  }
}
