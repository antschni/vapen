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

  Future<void> saveSession({
    required String baseUrl,
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
    required DateTime refreshExpiresAt,
  }) async {
    await _storage.write(key: _baseUrl, value: baseUrl);
    await _storage.write(key: _access, value: accessToken);
    await _storage.write(key: _refresh, value: refreshToken);
    await _storage.write(key: _accessExp, value: accessExpiresAt.toIso8601String());
    await _storage.write(key: _refreshExp, value: refreshExpiresAt.toIso8601String());
  }

  Future<String?> readBaseUrl() => _storage.read(key: _baseUrl);

  Future<String?> readAccessToken() => _storage.read(key: _access);

  Future<String?> readRefreshToken() => _storage.read(key: _refresh);

  Future<DateTime?> readAccessExpiresAt() async {
    final raw = await _storage.read(key: _accessExp);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clear() => _storage.deleteAll();
}
