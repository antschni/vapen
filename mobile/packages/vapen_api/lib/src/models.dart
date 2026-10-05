import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

@JsonSerializable()
class RegisterRequest {
  RegisterRequest({
    required this.email,
    required this.password,
    required this.displayName,
    required this.timezone,
  });

  final String email;
  final String password;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String timezone;

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

@JsonSerializable()
class LoginRequest {
  LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class RefreshRequest {
  RefreshRequest({required this.refreshToken});

  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  Map<String, dynamic> toJson() => _$RefreshRequestToJson(this);
}

@JsonSerializable()
class User {
  User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.timezone,
    required this.createdAt,
  });

  final String id;
  final String email;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String timezone;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class TokenPair {
  TokenPair({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'access_token_expires_at')
  final DateTime accessTokenExpiresAt;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @JsonKey(name: 'refresh_token_expires_at')
  final DateTime refreshTokenExpiresAt;
  final User user;

  factory TokenPair.fromJson(Map<String, dynamic> json) =>
      _$TokenPairFromJson(json);
}

@JsonSerializable()
class PrivacySettings {
  PrivacySettings({
    required this.shareLiveStatus,
    required this.shareUsageSummary,
    required this.shareUsageDetail,
    required this.shareDeviceStats,
    required this.showInLeaderboard,
  });

  @JsonKey(name: 'share_live_status')
  final bool shareLiveStatus;
  @JsonKey(name: 'share_usage_summary')
  final bool shareUsageSummary;
  @JsonKey(name: 'share_usage_detail')
  final bool shareUsageDetail;
  @JsonKey(name: 'share_device_stats')
  final bool shareDeviceStats;
  @JsonKey(name: 'show_in_leaderboard')
  final bool showInLeaderboard;

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      _$PrivacySettingsFromJson(json);
  Map<String, dynamic> toJson() => _$PrivacySettingsToJson(this);
}

@JsonSerializable()
class DeviceStatus {
  DeviceStatus({
    required this.recordedAt,
    this.batteryPercent,
    this.isCharging,
    this.liquidPercent,
    this.puffCounterTotal,
    this.powerMode,
    this.childLock,
    this.firmwareVersion,
  });

  @JsonKey(name: 'recorded_at')
  final DateTime recordedAt;
  @JsonKey(name: 'battery_percent')
  final int? batteryPercent;
  @JsonKey(name: 'is_charging')
  final bool? isCharging;
  @JsonKey(name: 'liquid_percent')
  final int? liquidPercent;
  @JsonKey(name: 'puff_counter_total')
  final int? puffCounterTotal;
  @JsonKey(name: 'power_mode')
  final String? powerMode;
  @JsonKey(name: 'child_lock')
  final bool? childLock;
  @JsonKey(name: 'firmware_version')
  final String? firmwareVersion;

  factory DeviceStatus.fromJson(Map<String, dynamic> json) =>
      _$DeviceStatusFromJson(json);
}

@JsonSerializable()
class Device {
  Device({
    required this.id,
    required this.model,
    required this.name,
    required this.hardwareId,
    required this.createdAt,
    this.firmwareVersion,
    this.lastSeenAt,
    this.latestStatus,
  });

  final String id;
  final String model;
  final String name;
  @JsonKey(name: 'hardware_id')
  final String hardwareId;
  @JsonKey(name: 'firmware_version')
  final String? firmwareVersion;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'last_seen_at')
  final DateTime? lastSeenAt;
  @JsonKey(name: 'latest_status')
  final DeviceStatus? latestStatus;

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
}

@JsonSerializable()
class CreateDeviceRequest {
  CreateDeviceRequest({
    required this.model,
    required this.name,
    required this.hardwareId,
    this.firmwareVersion,
  });

  final String model;
  final String name;
  @JsonKey(name: 'hardware_id')
  final String hardwareId;
  @JsonKey(name: 'firmware_version')
  final String? firmwareVersion;

  Map<String, dynamic> toJson() => _$CreateDeviceRequestToJson(this);
}

@JsonSerializable()
class IngestTokenCreated {
  IngestTokenCreated({
    required this.id,
    required this.name,
    required this.token,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String token;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  factory IngestTokenCreated.fromJson(Map<String, dynamic> json) =>
      _$IngestTokenCreatedFromJson(json);
}

@JsonSerializable()
class UsageTotals {
  UsageTotals({
    required this.puffCount,
    required this.totalDurationMs,
    required this.avgDurationMs,
    required this.maxDurationMs,
    required this.activeDays,
  });

  @JsonKey(name: 'puff_count')
  final int puffCount;
  @JsonKey(name: 'total_duration_ms')
  final int totalDurationMs;
  @JsonKey(name: 'avg_duration_ms')
  final int avgDurationMs;
  @JsonKey(name: 'max_duration_ms')
  final int maxDurationMs;
  @JsonKey(name: 'active_days')
  final int activeDays;

  factory UsageTotals.fromJson(Map<String, dynamic> json) =>
      _$UsageTotalsFromJson(json);
}

@JsonSerializable()
class UsagePeriodTotals {
  UsagePeriodTotals({
    required this.puffCount,
    required this.totalDurationMs,
  });

  @JsonKey(name: 'puff_count')
  final int puffCount;
  @JsonKey(name: 'total_duration_ms')
  final int totalDurationMs;

  factory UsagePeriodTotals.fromJson(Map<String, dynamic> json) =>
      _$UsagePeriodTotalsFromJson(json);
}

@JsonSerializable()
class UsageSeriesPoint {
  UsageSeriesPoint({
    required this.bucketStart,
    required this.puffCount,
    required this.totalDurationMs,
    required this.avgDurationMs,
    required this.maxDurationMs,
  });

  @JsonKey(name: 'bucket_start')
  final DateTime bucketStart;
  @JsonKey(name: 'puff_count')
  final int puffCount;
  @JsonKey(name: 'total_duration_ms')
  final int totalDurationMs;
  @JsonKey(name: 'avg_duration_ms')
  final int avgDurationMs;
  @JsonKey(name: 'max_duration_ms')
  final int maxDurationMs;

  factory UsageSeriesPoint.fromJson(Map<String, dynamic> json) =>
      _$UsageSeriesPointFromJson(json);
}

@JsonSerializable()
class HeatmapPoint {
  HeatmapPoint({
    required this.isoWeekday,
    required this.hour,
    required this.puffCount,
    required this.totalDurationMs,
  });

  @JsonKey(name: 'iso_weekday')
  final int isoWeekday;
  final int hour;
  @JsonKey(name: 'puff_count')
  final int puffCount;
  @JsonKey(name: 'total_duration_ms')
  final int totalDurationMs;

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) =>
      _$HeatmapPointFromJson(json);
}

@JsonSerializable()
class UsageStats {
  UsageStats({
    required this.userId,
    this.deviceId,
    required this.from,
    required this.to,
    required this.bucket,
    required this.tz,
    required this.totals,
    required this.previousPeriod,
    required this.series,
    required this.heatmap,
  });

  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  final DateTime from;
  final DateTime to;
  final String bucket;
  final String tz;
  final UsageTotals totals;
  @JsonKey(name: 'previous_period')
  final UsagePeriodTotals previousPeriod;
  final List<UsageSeriesPoint> series;
  final List<HeatmapPoint> heatmap;

  factory UsageStats.fromJson(Map<String, dynamic> json) =>
      _$UsageStatsFromJson(json);
}

@JsonSerializable()
class GroupSummary {
  GroupSummary({
    required this.id,
    required this.name,
    required this.role,
    required this.memberCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String role;
  @JsonKey(name: 'member_count')
  final int memberCount;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  factory GroupSummary.fromJson(Map<String, dynamic> json) =>
      _$GroupSummaryFromJson(json);
}

@JsonSerializable()
class GroupMember {
  GroupMember({
    required this.groupId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  @JsonKey(name: 'group_id')
  final String groupId;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String role;
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;

  factory GroupMember.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberFromJson(json);
}

@JsonSerializable()
class Group {
  Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberCount,
    required this.createdAt,
    required this.members,
    this.inviteCode,
  });

  final String id;
  final String name;
  @JsonKey(name: 'owner_id')
  final String ownerId;
  @JsonKey(name: 'invite_code')
  final String? inviteCode;
  @JsonKey(name: 'member_count')
  final int memberCount;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final List<GroupMember> members;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}

@JsonSerializable()
class GroupOverview {
  GroupOverview({
    required this.group,
    required this.from,
    required this.to,
    required this.tz,
    required this.members,
    required this.leaderboard,
  });

  final Map<String, dynamic> group;
  final DateTime from;
  final DateTime to;
  final String tz;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> leaderboard;

  factory GroupOverview.fromJson(Map<String, dynamic> json) =>
      _$GroupOverviewFromJson(json);
}

@JsonSerializable()
class GroupPrivacy {
  GroupPrivacy({
    required this.defaults,
    required this.overrides,
    required this.effective,
  });

  final PrivacySettings defaults;
  final Map<String, dynamic> overrides;
  final PrivacySettings effective;

  factory GroupPrivacy.fromJson(Map<String, dynamic> json) =>
      _$GroupPrivacyFromJson(json);
}
