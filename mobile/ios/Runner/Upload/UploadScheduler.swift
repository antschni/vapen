import BackgroundTasks
import Foundation

/// Retries pending uploads from the background — the iOS stand-in for Android's `UploadWorker`.
/// iOS decides when a refresh task actually runs; BLE wake-ups and app resume flush as well.
enum UploadScheduler {
  /// Must also be listed under `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
  static let taskIdentifier = "dev.vapen.vapen.upload"
  private static let maxBatches = 50

  /// Call before `application(_:didFinishLaunchingWithOptions:)` returns.
  static func register(uploader: @escaping () -> IngestUploader) {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
      let work = Task {
        let done = await drain(uploader())
        if !done { enqueue() }
        task.setTaskCompleted(success: done)
      }
      task.expirationHandler = {
        work.cancel()
        enqueue()
      }
    }
  }

  /// Uploads pending events once iOS grants background time, retrying until the queue is empty.
  static func enqueue() {
    let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      NSLog("Vapen: scheduling background upload failed: %@", error.localizedDescription)
    }
  }

  /// Returns true when nothing is left to retry.
  private static func drain(_ uploader: IngestUploader) async -> Bool {
    for _ in 0..<maxBatches {
      if Task.isCancelled { return false }
      switch await uploader.flush() {
      case .success:
        continue
      case .nothingToSend, .authError, .noCredentials:
        return true
      default:
        return false
      }
    }
    return true
  }
}
