// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) =>
    RegisterRequest(
      email: json['email'] as String,
      password: json['password'] as String,
      displayName: json['display_name'] as String,
      timezone: json['timezone'] as String,
    );

Map<String, dynamic> _$RegisterRequestToJson(RegisterRequest instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
      'display_name': instance.displayName,
      'timezone': instance.timezone,
    };

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
  email: json['email'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{'email': instance.email, 'password': instance.password};

RefreshRequest _$RefreshRequestFromJson(Map<String, dynamic> json) =>
    RefreshRequest(refreshToken: json['refresh_token'] as String);

Map<String, dynamic> _$RefreshRequestToJson(RefreshRequest instance) =>
    <String, dynamic>{'refresh_token': instance.refreshToken};

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  email: json['email'] as String,
  displayName: json['display_name'] as String,
  timezone: json['timezone'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'display_name': instance.displayName,
  'timezone': instance.timezone,
  'created_at': instance.createdAt.toIso8601String(),
};

TokenPair _$TokenPairFromJson(Map<String, dynamic> json) => TokenPair(
  accessToken: json['access_token'] as String,
  accessTokenExpiresAt: DateTime.parse(
    json['access_token_expires_at'] as String,
  ),
  refreshToken: json['refresh_token'] as String,
  refreshTokenExpiresAt: DateTime.parse(
    json['refresh_token_expires_at'] as String,
  ),
  user: User.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TokenPairToJson(TokenPair instance) => <String, dynamic>{
  'access_token': instance.accessToken,
  'access_token_expires_at': instance.accessTokenExpiresAt.toIso8601String(),
  'refresh_token': instance.refreshToken,
  'refresh_token_expires_at': instance.refreshTokenExpiresAt.toIso8601String(),
  'user': instance.user,
};

PrivacySettings _$PrivacySettingsFromJson(Map<String, dynamic> json) =>
    PrivacySettings(
      shareLiveStatus: json['share_live_status'] as bool,
      shareUsageSummary: json['share_usage_summary'] as bool,
      shareUsageDetail: json['share_usage_detail'] as bool,
      shareDeviceStats: json['share_device_stats'] as bool,
      showInLeaderboard: json['show_in_leaderboard'] as bool,
    );

Map<String, dynamic> _$PrivacySettingsToJson(PrivacySettings instance) =>
    <String, dynamic>{
      'share_live_status': instance.shareLiveStatus,
      'share_usage_summary': instance.shareUsageSummary,
      'share_usage_detail': instance.shareUsageDetail,
      'share_device_stats': instance.shareDeviceStats,
      'show_in_leaderboard': instance.showInLeaderboard,
    };

DeviceStatus _$DeviceStatusFromJson(Map<String, dynamic> json) => DeviceStatus(
  recordedAt: DateTime.parse(json['recorded_at'] as String),
  batteryPercent: (json['battery_percent'] as num?)?.toInt(),
  isCharging: json['is_charging'] as bool?,
  liquidPercent: (json['liquid_percent'] as num?)?.toInt(),
  puffCounterTotal: (json['puff_counter_total'] as num?)?.toInt(),
  powerMode: json['power_mode'] as String?,
  childLock: json['child_lock'] as bool?,
  firmwareVersion: json['firmware_version'] as String?,
);

Map<String, dynamic> _$DeviceStatusToJson(DeviceStatus instance) =>
    <String, dynamic>{
      'recorded_at': instance.recordedAt.toIso8601String(),
      'battery_percent': instance.batteryPercent,
      'is_charging': instance.isCharging,
      'liquid_percent': instance.liquidPercent,
      'puff_counter_total': instance.puffCounterTotal,
      'power_mode': instance.powerMode,
      'child_lock': instance.childLock,
      'firmware_version': instance.firmwareVersion,
    };

Device _$DeviceFromJson(Map<String, dynamic> json) => Device(
  id: json['id'] as String,
  model: json['model'] as String,
  name: json['name'] as String,
  hardwareId: json['hardware_id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  firmwareVersion: json['firmware_version'] as String?,
  lastSeenAt: json['last_seen_at'] == null
      ? null
      : DateTime.parse(json['last_seen_at'] as String),
  latestStatus: json['latest_status'] == null
      ? null
      : DeviceStatus.fromJson(json['latest_status'] as Map<String, dynamic>),
);

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'id': instance.id,
  'model': instance.model,
  'name': instance.name,
  'hardware_id': instance.hardwareId,
  'firmware_version': instance.firmwareVersion,
  'created_at': instance.createdAt.toIso8601String(),
  'last_seen_at': instance.lastSeenAt?.toIso8601String(),
  'latest_status': instance.latestStatus,
};

CreateDeviceRequest _$CreateDeviceRequestFromJson(Map<String, dynamic> json) =>
    CreateDeviceRequest(
      model: json['model'] as String,
      name: json['name'] as String,
      hardwareId: json['hardware_id'] as String,
      firmwareVersion: json['firmware_version'] as String?,
    );

Map<String, dynamic> _$CreateDeviceRequestToJson(
  CreateDeviceRequest instance,
) => <String, dynamic>{
  'model': instance.model,
  'name': instance.name,
  'hardware_id': instance.hardwareId,
  'firmware_version': instance.firmwareVersion,
};

IngestTokenCreated _$IngestTokenCreatedFromJson(Map<String, dynamic> json) =>
    IngestTokenCreated(
      id: json['id'] as String,
      name: json['name'] as String,
      token: json['token'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$IngestTokenCreatedToJson(IngestTokenCreated instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'token': instance.token,
      'created_at': instance.createdAt.toIso8601String(),
    };

UsageTotals _$UsageTotalsFromJson(Map<String, dynamic> json) => UsageTotals(
  puffCount: (json['puff_count'] as num).toInt(),
  totalDurationMs: (json['total_duration_ms'] as num).toInt(),
  avgDurationMs: (json['avg_duration_ms'] as num).toInt(),
  maxDurationMs: (json['max_duration_ms'] as num).toInt(),
  activeDays: (json['active_days'] as num).toInt(),
);

Map<String, dynamic> _$UsageTotalsToJson(UsageTotals instance) =>
    <String, dynamic>{
      'puff_count': instance.puffCount,
      'total_duration_ms': instance.totalDurationMs,
      'avg_duration_ms': instance.avgDurationMs,
      'max_duration_ms': instance.maxDurationMs,
      'active_days': instance.activeDays,
    };

UsagePeriodTotals _$UsagePeriodTotalsFromJson(Map<String, dynamic> json) =>
    UsagePeriodTotals(
      puffCount: (json['puff_count'] as num).toInt(),
      totalDurationMs: (json['total_duration_ms'] as num).toInt(),
    );

Map<String, dynamic> _$UsagePeriodTotalsToJson(UsagePeriodTotals instance) =>
    <String, dynamic>{
      'puff_count': instance.puffCount,
      'total_duration_ms': instance.totalDurationMs,
    };

UsageSeriesPoint _$UsageSeriesPointFromJson(Map<String, dynamic> json) =>
    UsageSeriesPoint(
      bucketStart: DateTime.parse(json['bucket_start'] as String),
      puffCount: (json['puff_count'] as num).toInt(),
      totalDurationMs: (json['total_duration_ms'] as num).toInt(),
      avgDurationMs: (json['avg_duration_ms'] as num).toInt(),
      maxDurationMs: (json['max_duration_ms'] as num).toInt(),
    );

Map<String, dynamic> _$UsageSeriesPointToJson(UsageSeriesPoint instance) =>
    <String, dynamic>{
      'bucket_start': instance.bucketStart.toIso8601String(),
      'puff_count': instance.puffCount,
      'total_duration_ms': instance.totalDurationMs,
      'avg_duration_ms': instance.avgDurationMs,
      'max_duration_ms': instance.maxDurationMs,
    };

HeatmapPoint _$HeatmapPointFromJson(Map<String, dynamic> json) => HeatmapPoint(
  isoWeekday: (json['iso_weekday'] as num).toInt(),
  hour: (json['hour'] as num).toInt(),
  puffCount: (json['puff_count'] as num).toInt(),
  totalDurationMs: (json['total_duration_ms'] as num).toInt(),
);

Map<String, dynamic> _$HeatmapPointToJson(HeatmapPoint instance) =>
    <String, dynamic>{
      'iso_weekday': instance.isoWeekday,
      'hour': instance.hour,
      'puff_count': instance.puffCount,
      'total_duration_ms': instance.totalDurationMs,
    };

UsageStats _$UsageStatsFromJson(Map<String, dynamic> json) => UsageStats(
  userId: json['user_id'] as String,
  deviceId: json['device_id'] as String?,
  from: DateTime.parse(json['from'] as String),
  to: DateTime.parse(json['to'] as String),
  bucket: json['bucket'] as String,
  tz: json['tz'] as String,
  totals: UsageTotals.fromJson(json['totals'] as Map<String, dynamic>),
  previousPeriod: UsagePeriodTotals.fromJson(
    json['previous_period'] as Map<String, dynamic>,
  ),
  series: (json['series'] as List<dynamic>)
      .map((e) => UsageSeriesPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
  heatmap: (json['heatmap'] as List<dynamic>)
      .map((e) => HeatmapPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$UsageStatsToJson(UsageStats instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'device_id': instance.deviceId,
      'from': instance.from.toIso8601String(),
      'to': instance.to.toIso8601String(),
      'bucket': instance.bucket,
      'tz': instance.tz,
      'totals': instance.totals,
      'previous_period': instance.previousPeriod,
      'series': instance.series,
      'heatmap': instance.heatmap,
    };

GroupSummary _$GroupSummaryFromJson(Map<String, dynamic> json) => GroupSummary(
  id: json['id'] as String,
  name: json['name'] as String,
  role: json['role'] as String,
  memberCount: (json['member_count'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$GroupSummaryToJson(GroupSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'role': instance.role,
      'member_count': instance.memberCount,
      'created_at': instance.createdAt.toIso8601String(),
    };

GroupMember _$GroupMemberFromJson(Map<String, dynamic> json) => GroupMember(
  groupId: json['group_id'] as String,
  userId: json['user_id'] as String,
  displayName: json['display_name'] as String,
  role: json['role'] as String,
  joinedAt: DateTime.parse(json['joined_at'] as String),
);

Map<String, dynamic> _$GroupMemberToJson(GroupMember instance) =>
    <String, dynamic>{
      'group_id': instance.groupId,
      'user_id': instance.userId,
      'display_name': instance.displayName,
      'role': instance.role,
      'joined_at': instance.joinedAt.toIso8601String(),
    };

Group _$GroupFromJson(Map<String, dynamic> json) => Group(
  id: json['id'] as String,
  name: json['name'] as String,
  ownerId: json['owner_id'] as String,
  memberCount: (json['member_count'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  members: (json['members'] as List<dynamic>)
      .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
      .toList(),
  inviteCode: json['invite_code'] as String?,
);

Map<String, dynamic> _$GroupToJson(Group instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'owner_id': instance.ownerId,
  'invite_code': instance.inviteCode,
  'member_count': instance.memberCount,
  'created_at': instance.createdAt.toIso8601String(),
  'members': instance.members,
};

GroupOverview _$GroupOverviewFromJson(Map<String, dynamic> json) =>
    GroupOverview(
      group: json['group'] as Map<String, dynamic>,
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      tz: json['tz'] as String,
      members: (json['members'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      leaderboard: (json['leaderboard'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );

Map<String, dynamic> _$GroupOverviewToJson(GroupOverview instance) =>
    <String, dynamic>{
      'group': instance.group,
      'from': instance.from.toIso8601String(),
      'to': instance.to.toIso8601String(),
      'tz': instance.tz,
      'members': instance.members,
      'leaderboard': instance.leaderboard,
    };

GroupPrivacy _$GroupPrivacyFromJson(Map<String, dynamic> json) => GroupPrivacy(
  defaults: PrivacySettings.fromJson(json['defaults'] as Map<String, dynamic>),
  overrides: json['overrides'] as Map<String, dynamic>,
  effective: PrivacySettings.fromJson(
    json['effective'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$GroupPrivacyToJson(GroupPrivacy instance) =>
    <String, dynamic>{
      'defaults': instance.defaults,
      'overrides': instance.overrides,
      'effective': instance.effective,
    };
