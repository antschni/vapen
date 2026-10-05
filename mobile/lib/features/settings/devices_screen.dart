import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/relative_time_format.dart';
import '../../core/ui/widgets.dart';
import '../../data/api/api_providers.dart';
import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  List<Device>? _devices;
  String? _activeDeviceId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = _devices == null;
      _error = null;
    });
    try {
      final list = await ref.read(apiClientProvider).listDevices();
      final activeId = await ref.read(tokenStorageProvider).readActiveDeviceId();
      if (!mounted) return;
      setState(() {
        _devices = list;
        _activeDeviceId = activeId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.genericError;
      });
    }
  }

  Future<void> _openDevice(Device device) async {
    final deleted = await context.push<bool>('/more/devices/${device.id}');
    if (deleted == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDevices = (_devices ?? const []).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      floatingActionButton: hasDevices
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/pairing'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.pairDeviceTitle),
            )
          : null,
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final devices = _devices ?? [];
    if (devices.isEmpty) {
      return EmptyState(
        icon: Icons.bluetooth_searching_rounded,
        title: l10n.devicesEmpty,
        message: l10n.devicesEmptyHint,
        action: FilledButton.icon(
          onPressed: () => context.push('/pairing'),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.pairDeviceTitle),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: devices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _DeviceTile(
          device: devices[i],
          isActive: devices[i].id == _activeDeviceId,
          l10n: l10n,
          onTap: () => _openDevice(devices[i]),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isActive,
    required this.l10n,
    required this.onTap,
  });

  final Device device;
  final bool isActive;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = device.latestStatus;
    final battery = status?.batteryPercent;
    final lastSeen = device.lastSeenAt != null
        ? '${l10n.deviceLastSeen} ${formatRelativeTimeDe(device.lastSeenAt!)}'
        : l10n.deviceNeverSeen;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconBadge(
                icon: Icons.vaping_rooms_outlined,
                color: isActive ? scheme.primary : scheme.outline,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.phone_android_rounded, size: 16, color: scheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastSeen,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (battery != null) ...[
                const SizedBox(width: 8),
                _BatteryBadge(percent: battery, charging: status?.isCharging == true),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryBadge extends StatelessWidget {
  const _BatteryBadge({required this.percent, required this.charging});

  final int percent;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final low = percent <= 15;
    final color = low ? scheme.error : scheme.onSurfaceVariant;
    final icon = charging
        ? Icons.battery_charging_full_rounded
        : percent > 80
            ? Icons.battery_full_rounded
            : percent > 50
                ? Icons.battery_5_bar_rounded
                : percent > 20
                    ? Icons.battery_3_bar_rounded
                    : Icons.battery_1_bar_rounded;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        Text('$percent %', style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
