import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/config.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

class SessionState {
  const SessionState({
    this.baseUrl,
    this.accessToken,
    this.user,
    this.loading = false,
  });

  final String? baseUrl;
  final String? accessToken;
  final User? user;
  final bool loading;

  bool get isAuthenticated => accessToken != null && user != null;

  SessionState copyWith({
    String? baseUrl,
    String? accessToken,
    User? user,
    bool? loading,
  }) {
    return SessionState(
      baseUrl: baseUrl ?? this.baseUrl,
      accessToken: accessToken ?? this.accessToken,
      user: user ?? this.user,
      loading: loading ?? this.loading,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(_restore);
    return const SessionState(loading: true);
  }

  TokenStorage get _storage => ref.read(tokenStorageProvider);

  Future<void> _restore() async {
    final baseUrl = await _storage.readBaseUrl() ?? defaultBaseUrl();
    final token = await _storage.readAccessToken();
    if (token == null) {
      state = SessionState(baseUrl: baseUrl, loading: false);
      return;
    }
    try {
      final client = VapenApiClient(baseUrl: baseUrl, accessToken: token);
      final user = await client.getMe();
      state = SessionState(baseUrl: baseUrl, accessToken: token, user: user, loading: false);
    } catch (_) {
      await _storage.clear();
      state = SessionState(baseUrl: baseUrl, loading: false);
    }
  }

  Future<void> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(loading: true);
    final client = VapenApiClient(baseUrl: baseUrl);
    final pair = await client.login(LoginRequest(email: email, password: password));
    await _storage.saveSession(
      baseUrl: baseUrl,
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      accessExpiresAt: pair.accessTokenExpiresAt,
      refreshExpiresAt: pair.refreshTokenExpiresAt,
    );
    state = SessionState(
      baseUrl: baseUrl,
      accessToken: pair.accessToken,
      user: pair.user,
      loading: false,
    );
  }

  Future<void> register({
    required String baseUrl,
    required String email,
    required String password,
    required String displayName,
    required String timezone,
  }) async {
    state = state.copyWith(loading: true);
    final client = VapenApiClient(baseUrl: baseUrl);
    final pair = await client.register(
      RegisterRequest(
        email: email,
        password: password,
        displayName: displayName,
        timezone: timezone,
      ),
    );
    await _storage.saveSession(
      baseUrl: baseUrl,
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      accessExpiresAt: pair.accessTokenExpiresAt,
      refreshExpiresAt: pair.refreshTokenExpiresAt,
    );
    state = SessionState(
      baseUrl: baseUrl,
      accessToken: pair.accessToken,
      user: pair.user,
      loading: false,
    );
  }

  void setUser(User user) {
    state = state.copyWith(user: user);
  }

  Future<void> clearSession() async {
    await _storage.clear();
    state = SessionState(baseUrl: state.baseUrl, loading: false);
  }

  Future<void> logout() async {
    final baseUrl = state.baseUrl;
    final token = state.accessToken;
    if (baseUrl != null && token != null) {
      try {
        await VapenApiClient(baseUrl: baseUrl, accessToken: token).logout();
      } catch (_) {
        // ignore
      }
    }
    await clearSession();
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
