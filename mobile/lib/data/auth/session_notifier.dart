import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/config.dart';
import '../native/tracking_bridge.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

class SessionState {
  const SessionState({
    this.baseUrl,
    this.accessToken,
    this.user,
    this.loading = false,
    this.serverSetupComplete = false,
  });

  final String? baseUrl;
  final String? accessToken;
  final User? user;
  final bool loading;
  final bool serverSetupComplete;

  bool get isAuthenticated => accessToken != null && user != null;

  SessionState copyWith({
    String? baseUrl,
    String? accessToken,
    User? user,
    bool? loading,
    bool? serverSetupComplete,
  }) {
    return SessionState(
      baseUrl: baseUrl ?? this.baseUrl,
      accessToken: accessToken ?? this.accessToken,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      serverSetupComplete: serverSetupComplete ?? this.serverSetupComplete,
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

  Future<String> _resolvedServerUrl() async {
    final fromSession = await _storage.readBaseUrl();
    if (fromSession != null && fromSession.isNotEmpty) return fromSession;
    final preferred = await _storage.readPreferredServerUrl();
    if (preferred != null && preferred.isNotEmpty) return preferred;
    return defaultBaseUrl();
  }

  Future<bool> _resolveServerSetupComplete() async {
    if (await _storage.readServerSetupComplete()) return true;
    final preferred = await _storage.readPreferredServerUrl();
    if (preferred != null && preferred.isNotEmpty) {
      await _storage.saveServerSetupComplete(true);
      return true;
    }
    return false;
  }

  static const _restoreTimeout = Duration(seconds: 20);

  Future<void> _restore() async {
    try {
      final baseUrl = await _resolvedServerUrl();
      final setupComplete = await _resolveServerSetupComplete();
      var token = await _storage.readAccessToken();
      final refresh = await _storage.readRefreshToken();
      final cachedUser = await _storage.readUser();
      if ((token == null || token.isEmpty) && (refresh == null || refresh.isEmpty)) {
        state = SessionState(
          baseUrl: baseUrl,
          serverSetupComplete: setupComplete,
          loading: false,
        );
        return;
      }

      final exp = await _storage.readAccessExpiresAt();
      final accessStale = token == null ||
          token.isEmpty ||
          (exp != null && !exp.isAfter(DateTime.now().add(const Duration(minutes: 1))));
      if (accessStale && refresh != null && refresh.isNotEmpty) {
        try {
          final pair = await _refreshSession(baseUrl, refresh);
          if (pair == null) {
            await _storage.clearSession();
            state = SessionState(
              baseUrl: baseUrl,
              serverSetupComplete: setupComplete,
              loading: false,
            );
            return;
          }
          token = pair.accessToken;
          state = SessionState(
            baseUrl: baseUrl,
            accessToken: pair.accessToken,
            user: pair.user,
            serverSetupComplete: true,
            loading: false,
          );
          return;
        } catch (_) {
          _restoreCached(
            baseUrl: baseUrl,
            token: token,
            user: cachedUser,
            setupComplete: setupComplete,
          );
          return;
        }
      }

      if (token == null || token.isEmpty) {
        state = SessionState(
          baseUrl: baseUrl,
          serverSetupComplete: setupComplete,
          loading: false,
        );
        return;
      }

      try {
        final user = await VapenApiClient(baseUrl: baseUrl, accessToken: token)
            .getMe()
            .timeout(_restoreTimeout);
        await _storage.saveUser(user);
        state = SessionState(
          baseUrl: baseUrl,
          accessToken: token,
          user: user,
          serverSetupComplete: true,
          loading: false,
        );
      } on VapenApiException catch (e) {
        if (e.problem.status == 401 && refresh != null && refresh.isNotEmpty) {
          try {
            final pair = await _refreshSession(baseUrl, refresh);
            if (pair == null) {
              await _storage.clearSession();
              state = SessionState(
                baseUrl: baseUrl,
                serverSetupComplete: setupComplete,
                loading: false,
              );
              return;
            }
            state = SessionState(
              baseUrl: baseUrl,
              accessToken: pair.accessToken,
              user: pair.user,
              serverSetupComplete: true,
              loading: false,
            );
            return;
          } catch (_) {
            _restoreCached(
              baseUrl: baseUrl,
              token: token,
              user: cachedUser,
              setupComplete: setupComplete,
            );
            return;
          }
        }
        _restoreCached(
          baseUrl: baseUrl,
          token: token,
          user: cachedUser,
          setupComplete: setupComplete,
        );
      } catch (_) {
        _restoreCached(
          baseUrl: baseUrl,
          token: token,
          user: cachedUser,
          setupComplete: setupComplete,
        );
      }
    } catch (_) {
      state = SessionState(
        baseUrl: defaultBaseUrl(),
        serverSetupComplete: false,
        loading: false,
      );
    }
  }

  /// Keeps a stored login when the server is briefly unreachable.
  /// Only an explicit auth rejection clears the session.
  void _restoreCached({
    required String baseUrl,
    required String? token,
    required User? user,
    required bool setupComplete,
  }) {
    if (token != null && token.isNotEmpty && user != null) {
      state = SessionState(
        baseUrl: baseUrl,
        accessToken: token,
        user: user,
        serverSetupComplete: true,
        loading: false,
      );
      return;
    }
    state = SessionState(
      baseUrl: baseUrl,
      serverSetupComplete: setupComplete,
      loading: false,
    );
  }

  /// Returns the new pair, null when the refresh token is rejected, or throws on network errors.
  Future<TokenPair?> _refreshSession(String baseUrl, String refreshToken) async {
    try {
      final pair = await VapenApiClient(baseUrl: baseUrl)
          .refresh(RefreshRequest(refreshToken: refreshToken))
          .timeout(_restoreTimeout);
      await _persistPair(baseUrl, pair);
      return pair;
    } on VapenApiException catch (e) {
      if (e.problem.status == 401 || e.problem.status == 400 || e.problem.status == 403) {
        return null;
      }
      rethrow;
    }
  }

  /// Validates `/healthz`, then persists the server URL for login/register.
  Future<void> testAndSaveServer(String baseUrl) async {
    final normalized = normalizeBaseUrl(baseUrl);
    if (!isAllowedBaseUrl(normalized, isRelease: kReleaseMode)) {
      throw ArgumentError('invalid_server_url');
    }
    await VapenApiClient(baseUrl: normalized).checkHealth();
    await _storage.savePreferredServerUrl(normalized);
    await _storage.saveServerSetupComplete(true);
    state = state.copyWith(baseUrl: normalized, serverSetupComplete: true, loading: false);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final normalized = normalizeBaseUrl(state.baseUrl ?? await _resolvedServerUrl());
    if (!state.serverSetupComplete) {
      throw StateError('server_not_configured');
    }
    final client = VapenApiClient(baseUrl: normalized);
    final pair = await client.login(LoginRequest(email: email, password: password));
    await _persistPair(normalized, pair);
    state = SessionState(
      baseUrl: normalized,
      accessToken: pair.accessToken,
      user: pair.user,
      serverSetupComplete: true,
      loading: false,
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String timezone,
  }) async {
    final normalized = normalizeBaseUrl(state.baseUrl ?? await _resolvedServerUrl());
    if (!state.serverSetupComplete) {
      throw StateError('server_not_configured');
    }
    final client = VapenApiClient(baseUrl: normalized);
    final pair = await client.register(
      RegisterRequest(
        email: email,
        password: password,
        displayName: displayName,
        timezone: timezone,
      ),
    );
    await _persistPair(normalized, pair);
    state = SessionState(
      baseUrl: normalized,
      accessToken: pair.accessToken,
      user: pair.user,
      serverSetupComplete: true,
      loading: false,
    );
  }

  Future<void> _persistPair(String baseUrl, TokenPair pair) async {
    await _storage.saveSession(
      baseUrl: baseUrl,
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      accessExpiresAt: pair.accessTokenExpiresAt,
      refreshExpiresAt: pair.refreshTokenExpiresAt,
    );
    await _storage.saveUser(pair.user);
  }

  /// Persists [baseUrl]. Logs out and clears native device credentials when the URL changes while signed in.
  Future<void> updateServerEndpoint(String baseUrl) async {
    final normalized = normalizeBaseUrl(baseUrl);
    if (!isAllowedBaseUrl(normalized, isRelease: kReleaseMode)) {
      throw ArgumentError('invalid_server_url');
    }
    await VapenApiClient(baseUrl: normalized).checkHealth();

    final previous = state.baseUrl ?? await _resolvedServerUrl();
    final changed = normalizeBaseUrl(previous) != normalized;

    if (changed && state.isAuthenticated) {
      await ref.read(trackingBridgeProvider).host.clearCredentials();
      await logout();
    }

    await _storage.savePreferredServerUrl(normalized);
    await _storage.saveServerSetupComplete(true);

    if (state.isAuthenticated) {
      state = state.copyWith(baseUrl: normalized, serverSetupComplete: true);
    } else {
      state = SessionState(
        baseUrl: normalized,
        serverSetupComplete: true,
        loading: false,
      );
    }
  }

  void setUser(User user) {
    state = state.copyWith(user: user);
  }

  Future<void> clearSession() async {
    await _storage.clearSession();
    final baseUrl = await _resolvedServerUrl();
    final setupComplete = await _resolveServerSetupComplete();
    state = SessionState(
      baseUrl: baseUrl,
      serverSetupComplete: setupComplete,
      loading: false,
    );
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
