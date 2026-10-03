import 'package:dio/dio.dart';

import 'models.dart';
import 'problem.dart';

/// REST client for `/api/v1` (base URL should be the server origin without path).
class VapenApiClient {
  VapenApiClient({
    required String baseUrl,
    Dio? dio,
    String? accessToken,
  })  : _dio = dio ?? Dio(),
        _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl {
    _dio.options.baseUrl = '$_baseUrl/api/v1';
    _dio.options.headers['Accept'] = 'application/json';
    if (accessToken != null) {
      setAccessToken(accessToken);
    }
  }

  final Dio _dio;
  final String _baseUrl;

  String get baseUrl => _baseUrl;

  void setAccessToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<TokenPair> register(RegisterRequest body) async {
    final response = await _request(() => _dio.post('/auth/register', data: body.toJson()));
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TokenPair> login(LoginRequest body) async {
    final response = await _request(() => _dio.post('/auth/login', data: body.toJson()));
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TokenPair> refresh(RefreshRequest body) async {
    final response = await _request(() => _dio.post('/auth/refresh', data: body.toJson()));
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _request(() => _dio.post('/auth/logout'));
  }

  Future<User> getMe() async {
    final response = await _request(() => _dio.get('/me'));
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<User> patchMe({String? displayName, String? timezone}) async {
    final response = await _request(
      () => _dio.patch('/me', data: {
        if (displayName != null) 'display_name': displayName,
        if (timezone != null) 'timezone': timezone,
      }),
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _request(
      () => _dio.post('/me/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
  }

  Future<Map<String, dynamic>> getDeviceStats(String deviceId, {String? bucket}) async {
    final response = await _request(
      () => _dio.get('/stats/devices/$deviceId', queryParameters: {
        if (bucket != null) 'bucket': bucket,
      }),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<PrivacySettings> getPrivacyDefaults() async {
    final response = await _request(() => _dio.get('/me/privacy-defaults'));
    return PrivacySettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PrivacySettings> putPrivacyDefaults(PrivacySettings body) async {
    final response =
        await _request(() => _dio.put('/me/privacy-defaults', data: body.toJson()));
    return PrivacySettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Device>> listDevices() async {
    final response = await _request(() => _dio.get('/devices'));
    return (response.data as List)
        .map((e) => Device.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Device> createDevice(CreateDeviceRequest body) async {
    final response = await _request(() => _dio.post('/devices', data: body.toJson()));
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  Future<IngestTokenCreated> createIngestToken(String deviceId, String name) async {
    final response = await _request(
      () => _dio.post('/devices/$deviceId/ingest-tokens', data: {'name': name}),
    );
    return IngestTokenCreated.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UsageStats> getUsageStats({
    DateTime? from,
    DateTime? to,
    String? bucket,
    String? tz,
    String? deviceId,
  }) async {
    final response = await _request(
      () => _dio.get('/stats/usage', queryParameters: {
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        if (bucket != null) 'bucket': bucket,
        if (tz != null) 'tz': tz,
        if (deviceId != null) 'device_id': deviceId,
      }),
    );
    return UsageStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<GroupSummary>> listGroups() async {
    final response = await _request(() => _dio.get('/groups'));
    return (response.data as List)
        .map((e) => GroupSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Group> createGroup(String name) async {
    final response = await _request(() => _dio.post('/groups', data: {'name': name}));
    return Group.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Group> joinGroup(String inviteCode) async {
    final response =
        await _request(() => _dio.post('/groups/join', data: {'invite_code': inviteCode}));
    return Group.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Group> getGroup(String id) async {
    final response = await _request(() => _dio.get('/groups/$id'));
    return Group.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupOverview> getGroupOverview(String id, {String? tz}) async {
    final response = await _request(
      () => _dio.get('/groups/$id/overview', queryParameters: {
        if (tz != null) 'tz': tz,
      }),
    );
    return GroupOverview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupPrivacy> getGroupPrivacy(String id) async {
    final response = await _request(() => _dio.get('/groups/$id/privacy'));
    return GroupPrivacy.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupPrivacy> putGroupPrivacy(String id, Map<String, dynamic> overrides) async {
    final response = await _request(
      () => _dio.put('/groups/$id/privacy', data: {'overrides': overrides}),
    );
    return GroupPrivacy.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Response<dynamic>> _request(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return response;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('code')) {
        final problem = ApiProblem.fromJson(data);
        int? retryAfter;
        final raw = e.response?.headers.value('retry-after');
        if (raw != null) {
          retryAfter = int.tryParse(raw);
        }
        throw VapenApiException(problem, retryAfterSeconds: retryAfter);
      }
      rethrow;
    }
  }
}
