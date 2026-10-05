import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _accessExp = 'access_exp';
  static const _refreshExp = 'refresh_exp';
  static const _baseUrl = 'base_url';
  static const _preferredServer = 'preferred_server_url';
  static const _serverSetupComplete = 'server_setup_complete';
  static const _activeDeviceId = 'active_device_id';

  Future<void> savePreferredServerUrl(String baseUrl) async {
    await _storage.write(key: _preferredServer, value: baseUrl);
  }

  Future<String?> readPreferredServerUrl() => _storage.read(key: _preferredServer);

  Future<void> saveServerSetupComplete(bool complete) async {
    await _storage.write(key: _serverSetupComplete, value: complete ? '1' : '0');
  }

  Future<bool> readServerSetupComplete() async {
    final raw = await _storage.read(key: _serverSetupComplete);
    return raw == '1';
  }

  Future<void> saveSession({
    required String baseUrl,
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
    required DateTime refreshExpiresAt,
  }) async {
    await savePreferredServerUrl(baseUrl);
    await saveServerSetupComplete(true);
    await _storage.write(key: _baseUrl, value: baseUrl);
    await _storage.write(key: _access, value: accessToken);
    await _storage.write(key: _refresh, value: refreshToken);
    await _storage.write(key: _accessExp, value: accessExpiresAt.toIso8601String());
    await _storage.write(key: _refreshExp, value: refreshExpiresAt.toIso8601String());
  }

  Future<String?> readBaseUrl() => _storage.read(key: _baseUrl);

  Future<String?> readAccessToken() => _storage.read(key: _access);

  Future<void> saveActiveDeviceId(String deviceId) =>
      _storage.write(key: _activeDeviceId, value: deviceId);

  Future<String?> readActiveDeviceId() => _storage.read(key: _activeDeviceId);

  Future<void> clearActiveDeviceId() => _storage.delete(key: _activeDeviceId);

  Future<String?> readRefreshToken() => _storage.read(key: _refresh);

  Future<DateTime?> readAccessExpiresAt() async {
    final raw = await _storage.read(key: _accessExp);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clearSession() async {
    for (final key in [_access, _refresh, _accessExp, _refreshExp, _baseUrl]) {
      await _storage.delete(key: key);
    }
  }
}
