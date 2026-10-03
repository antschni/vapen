import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vapen_api/vapen_api.dart';

import '../auth/session_notifier.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionProvider.notifier);
  final storage = ref.watch(tokenStorageProvider);
  final dio = Dio();
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      storage: storage,
      onLogout: () => session.clearSession(),
    ),
  );
  return dio;
});

final apiClientProvider = Provider<VapenApiClient>((ref) {
  final session = ref.watch(sessionProvider);
  final baseUrl = session.baseUrl ?? 'http://10.0.2.2:8080';
  final client = VapenApiClient(
    baseUrl: baseUrl,
    dio: ref.watch(dioProvider),
    accessToken: session.accessToken,
  );
  return client;
});
