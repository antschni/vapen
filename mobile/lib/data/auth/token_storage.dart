import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vapen_api/vapen_api.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? _encrypted,
        _legacy = storage == null ? _keystore : null;

  /// Survives process death more reliably than the default Keystore cipher.
  static const _encrypted = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  /// Previous installs wrote here. Reads fall back once and copy into [_encrypted].
  static const _keystore = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  final FlutterSecureStorage _storage;
  final FlutterSecureStorage? _legacy;

  Future<String?> _read(String key) async {
    final current = await _storage.read(key: key);
    if (current != null) return current;
    final legacy = _legacy;
    if (legacy == null) return null;
    final previous = await legacy.read(key: key);
    if (previous != null) {
      await _storage.write(key: key, value: previous);
    }
    return previous;
  }

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _accessExp = 'access_exp';
  static const _refreshExp = 'refresh_exp';
  static const _baseUrl = 'base_url';
  static const _preferredServer = 'preferred_server_url';
  static const _serverSetupComplete = 'server_setup_complete';
  static const _activeDeviceId = 'active_device_id';
  static const _user = 'user_json';

  Future<void> savePreferredServerUrl(String baseUrl) async {
    await _storage.write(key: _preferredServer, value: baseUrl);
  }

  Future<String?> readPreferredServerUrl() => _read(_preferredServer);

  Future<void> saveServerSetupComplete(bool complete) async {
    await _storage.write(key: _serverSetupComplete, value: complete ? '1' : '0');
  }

  Future<bool> readServerSetupComplete() async {
    final raw = await _read(_serverSetupComplete);
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

  Future<void> saveUser(User user) => _storage.write(key: _user, value: jsonEncode(user.toJson()));

  Future<User?> readUser() async {
    final raw = await _read(_user);
    if (raw == null || raw.isEmpty) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<String?> readBaseUrl() => _read(_baseUrl);

  Future<String?> readAccessToken() => _read(_access);

  Future<void> saveActiveDeviceId(String deviceId) =>
      _storage.write(key: _activeDeviceId, value: deviceId);

  Future<String?> readActiveDeviceId() => _read(_activeDeviceId);

  Future<void> clearActiveDeviceId() => _storage.delete(key: _activeDeviceId);

  Future<String?> readRefreshToken() => _read(_refresh);

  Future<DateTime?> readAccessExpiresAt() async {
    final raw = await _read(_accessExp);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clearSession() async {
    for (final key in [_access, _refresh, _accessExp, _refreshExp, _baseUrl, _user]) {
      await _storage.delete(key: key);
      await _legacy?.delete(key: key);
    }
  }
}
