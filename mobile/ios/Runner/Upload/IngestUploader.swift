import Foundation

enum UploadResult: Equatable {
  case success
  case nothingToSend
  case noCredentials
  case authError
  case serverError
  case rateLimited(retryAfterSeconds: Int64?)
  case networkError(String)
  case otherError(code: Int, body: String)
}

final class IngestUploader: @unchecked Sendable {
  private let credentials: CredentialStore
  private let store: PendingEventStore
  private let session: URLSession

  init(credentials: CredentialStore, store: PendingEventStore, session: URLSession = .shared) {
    self.credentials = credentials
    self.store = store
    self.session = session
  }

  func flush(maxBatch: Int = 100) async -> UploadResult {
    guard let creds = credentials.get() else { return .noCredentials }
    let batch = store.oldest(maxBatch)
    if batch.isEmpty { return .nothingToSend }

    let events: [Any] = batch.compactMap { row in
      try? JSONSerialization.jsonObject(with: Data(row.payloadJson.utf8))
    }
    let body: [String: Any] = [
      "device_id": creds.deviceId,
      "sent_at": ISO8601DateFormatter.vapen.string(from: Date()),
      "events": events,
    ]
    var base = creds.baseUrl
    while base.hasSuffix("/") { base.removeLast() }
    guard let url = URL(string: "\(base)/api/v1/ingest"),
          let payload = try? JSONSerialization.data(withJSONObject: body)
    else { return .otherError(code: 0, body: "Ungültige Server-URL") }

    var request = URLRequest(url: url, timeoutInterval: 30)
    request.httpMethod = "POST"
    request.setValue("Bearer \(creds.deviceToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = payload

    let exchange: (Data, URLResponse)
    do {
      exchange = try await session.data(for: request)
    } catch {
      return .networkError(error.localizedDescription)
    }
    let (data, response) = exchange
    guard let http = response as? HTTPURLResponse else { return .networkError("Keine HTTP-Antwort") }
    let responseBody = String(decoding: data, as: UTF8.self)
    switch http.statusCode {
    case 200:
      let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
      handleSuccess(batch, parsed)
      return .success
    case 401, 403:
      return .authError
    case 429:
      return .rateLimited(retryAfterSeconds: http.value(forHTTPHeaderField: "Retry-After").flatMap { Int64($0) })
    case 500...599:
      return .serverError
    default:
      return .otherError(code: http.statusCode, body: responseBody)
    }
  }

  private func handleSuccess(_ batch: [PendingEvent], _ parsed: [String: Any]) {
    let rejected = parsed["rejected"] as? [[String: Any]] ?? []
    let rejectedIds = Set(rejected.compactMap { $0["client_event_id"] as? String })
    // A 200 means the server processed the whole batch; everything not rejected is stored or a
    // duplicate. Counting from the front would keep events whenever a rejection sits mid-batch.
    let toRemove = batch.map(\.clientEventId).filter { !rejectedIds.contains($0) }
    store.deleteByIds(toRemove)
    for entry in rejected {
      guard let id = entry["client_event_id"] as? String,
            let row = batch.first(where: { $0.clientEventId == id })
      else { continue }
      store.insertDead(
        DeadEvent(
          clientEventId: id,
          type: row.type,
          payloadJson: row.payloadJson,
          reason: entry["message"] as? String ?? "rejected",
          createdAtEpochMs: row.createdAtEpochMs
        )
      )
      store.deleteByIds([id])
    }
    let total = store.count()
    if total > Self.maxPending {
      store.deleteByIds(store.oldest(total - Self.maxPending).map(\.clientEventId))
    }
  }

  private static let maxPending = 100_000
}
