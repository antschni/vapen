import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/relative_time_format.dart';
import '../../core/ui/widgets.dart';
import '../../data/api/api_providers.dart';
import '../../data/auth/session_notifier.dart';
import '../../data/native/tracking_bridge.dart';
import '../../l10n/app_localizations.dart';

class DeviceDetailScreen extends ConsumerStatefulWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> {
  Device? _device;
  String? _activeDeviceId;
  String? _error;
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final device = await api.getDevice(widget.deviceId);
      final bridge = ref.read(trackingBridgeProvider);
      final activeId = await ref.read(tokenStorageProvider).readActiveDeviceId() ??
          await bridge.host.getActiveDeviceId();
      if (!mounted) return;
      setState(() {
        _device = device;
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

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deviceDeleteTitle),
        content: Text(l10n.deviceDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.deviceDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final bridge = ref.read(trackingBridgeProvider);
      await ref.read(apiClientProvider).deleteDevice(widget.deviceId);
      final activeId = _activeDeviceId ??
          await ref.read(tokenStorageProvider).readActiveDeviceId() ??
          await bridge.host.getActiveDeviceId();
      if (activeId == widget.deviceId) {
        await bridge.host.clearCredentials();
        await ref.read(tokenStorageProvider).clearActiveDeviceId();
      }
      if (mounted) context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.genericError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deviceDetailTitle)),
      body: _buildBody(l10n, theme),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final device = _device!;
    final status = device.latestStatus;
    final isActiveHere = _activeDeviceId == device.id;
    final scheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconBadge(icon: Icons.vaping_rooms_outlined, color: scheme.primary, size: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          device.lastSeenAt != null
                              ? '${l10n.deviceLastSeen} ${formatRelativeTimeDe(device.lastSeenAt!)}'
                              : '${l10n.deviceLastSeen}: ${l10n.deviceNeverSeen}',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (isActiveHere) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_android_rounded, size: 14, color: scheme.onPrimaryContainer),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.deviceActiveOnPhone,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(l10n.deviceSectionStatus),
          if (status != null) ...[
            Row(
              children: [
                Expanded(
                  child: _GaugeTile(
                    icon: status.isCharging == true
                        ? Icons.battery_charging_full_rounded
                        : Icons.battery_std_rounded,
                    label: status.isCharging == true ? '${l10n.deviceBattery} · lädt' : l10n.deviceBattery,
                    percent: status.batteryPercent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GaugeTile(
                    icon: Icons.water_drop_rounded,
                    label: l10n.deviceLiquid,
                    percent: status.liquidPercent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GroupedCard(
              children: [
                if (status.puffCounterTotal != null)
                  _InfoRow(
                    icon: Icons.cloud_outlined,
                    label: 'Züge (Gerätezähler)',
                    value: NumberFormat.decimalPattern('de_DE').format(status.puffCounterTotal),
                  ),
                if (status.firmwareVersion != null && status.firmwareVersion!.isNotEmpty)
                  _InfoRow(icon: Icons.memory_rounded, label: l10n.deviceFirmware, value: status.firmwareVersion!),
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  label: l10n.deviceStatusRecorded,
                  value: formatRelativeTimeDe(status.recordedAt),
                ),
              ],
            ),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.deviceNoStatusYet,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SectionHeader(l10n.deviceSectionInfo),
          GroupedCard(
            children: [
              _InfoRow(
                icon: Icons.category_outlined,
                label: 'Modell',
                value: device.model == 'elfbar_master' ? 'Elfbar Master' : device.model,
              ),
              _InfoRow(
                icon: Icons.event_outlined,
                label: l10n.deviceRegistered,
                value: DateFormat('d. MMM yyyy', 'de_DE').format(device.createdAt.toLocal()),
              ),
              if (device.firmwareVersion != null && device.firmwareVersion!.isNotEmpty)
                _InfoRow(
                  icon: Icons.memory_rounded,
                  label: l10n.deviceFirmwareReported,
                  value: device.firmwareVersion!,
                ),
              _InfoRow(
                icon: Icons.fingerprint_rounded,
                label: l10n.deviceHardwareId,
                value: device.hardwareId,
                monospace: true,
              ),
            ],
          ),
          const SectionHeader('Gefahrenzone'),
          Card(
            color: scheme.errorContainer.withValues(alpha: 0.25),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.deviceDeleteConfirm,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _deleting ? null : _confirmDelete,
                    icon: _deleting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline_rounded),
                    label: Text(l10n.deviceDeleteAction),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeTile extends StatelessWidget {
  const _GaugeTile({required this.icon, required this.label, required this.percent});

  final IconData icon;
  final String label;
  final int? percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = percent?.clamp(0, 100);
    final color = value != null && value <= 15 ? scheme.error : scheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 52,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value == null ? 0 : value / 100,
                    strokeWidth: 5,
                    color: color,
                    backgroundColor: scheme.surfaceContainerHighest,
                    strokeCap: StrokeCap.round,
                  ),
                  Icon(icon, size: 22, color: color),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value != null ? '$value %' : '—', style: theme.textTheme.titleLarge),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.monospace = false});

  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      subtitle: SelectableText(
        value,
        style: (monospace ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace') : theme.textTheme.bodyLarge)
            ?.copyWith(color: theme.colorScheme.onSurface),
      ),
    );
  }
}

