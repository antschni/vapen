import 'dart:async';

import 'package:dio/dio.dart';
import 'package:vapen_api/vapen_api.dart';

import '../auth/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.storage,
    required this.onLogout,
  });

  final Dio dio;
  final TokenStorage storage;
  final void Function() onLogout;

  Completer<void>? _refreshCompleter;

  static const _retriedKey = 'auth_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await storage.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }
    final path = err.requestOptions.path;
    // A retried request that still gets 401 must not trigger another refresh (endless loop).
    if (path.contains('/auth/') || err.requestOptions.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    try {
      await _refreshSingleFlight();
      err.requestOptions.extra[_retriedKey] = true;
      final response = await dio.fetch(err.requestOptions);
      return handler.resolve(response);
    } on VapenApiException catch (e) {
      if (e.problem.status == 401 || e.problem.status == 400 || e.problem.status == 403) {
        onLogout();
      }
      return handler.next(err);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) onLogout();
      return handler.next(err);
    } catch (_) {
      return handler.next(err);
    }
  }

  Future<void> _refreshSingleFlight() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    final completer = _refreshCompleter = Completer<void>();
    // Without a waiter, a failed refresh would surface as an unhandled async error.
    completer.future.ignore();
    try {
      final refresh = await storage.readRefreshToken();
      final baseUrl = await storage.readBaseUrl();
      if (refresh == null || baseUrl == null) {
        throw StateError('no refresh token');
      }
      final client = VapenApiClient(baseUrl: baseUrl);
      final pair = await client.refresh(RefreshRequest(refreshToken: refresh));
      await storage.saveSession(
        baseUrl: baseUrl,
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        accessExpiresAt: pair.accessTokenExpiresAt,
        refreshExpiresAt: pair.refreshTokenExpiresAt,
      );
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }
}
