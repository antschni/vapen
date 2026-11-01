import Foundation
import Security

struct StoredCredentials: Codable, Equatable {
  let baseUrl: String
  let deviceId: String
  let deviceToken: String
  let hardwareId: String
}

/// Device token in the Keychain (readable after first unlock, so background uploads work while the
/// phone is locked); tracking flags in UserDefaults. Mirrors the Android `CredentialStore`.
final class CredentialStore {
  private let defaults: UserDefaults
  private let service = "dev.vapen.credentials"
  private let account = "native"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    // Keychain items outlive an app deletion; a fresh install must not inherit an old token.
    if !defaults.bool(forKey: Keys.installed) {
      deleteKeychainItem()
      defaults.set(true, forKey: Keys.installed)
    }
  }

  func save(_ credentials: StoredCredentials) {
    guard let data = try? JSONEncoder().encode(credentials) else { return }
    deleteKeychainItem()
    let item: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: data,
    ]
    SecItemAdd(item as CFDictionary, nil)
    trackingEnabled = true
  }

  func clear() {
    deleteKeychainItem()
    for key in [Keys.pairedAddress, Keys.trackingEnabled, Keys.simulation] {
      defaults.removeObject(forKey: key)
    }
  }

  func get() -> StoredCredentials? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data
    else { return nil }
    return try? JSONDecoder().decode(StoredCredentials.self, from: data)
  }

  var pairedBleAddress: String? {
    get { defaults.string(forKey: Keys.pairedAddress) }
    set { defaults.set(newValue, forKey: Keys.pairedAddress) }
  }

  var trackingEnabled: Bool {
    get { defaults.bool(forKey: Keys.trackingEnabled) }
    set { defaults.set(newValue, forKey: Keys.trackingEnabled) }
  }

  var simulationEnabled: Bool {
    get { defaults.bool(forKey: Keys.simulation) }
    set { defaults.set(newValue, forKey: Keys.simulation) }
  }

  private func deleteKeychainItem() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }

  private enum Keys {
    static let installed = "vapen.installed"
    static let pairedAddress = "vapen.paired_ble_address"
    static let trackingEnabled = "vapen.tracking_enabled"
    static let simulation = "vapen.simulation_enabled"
  }
}
