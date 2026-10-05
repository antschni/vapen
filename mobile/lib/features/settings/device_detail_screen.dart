import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/relative_time_format.dart';
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Erneut versuchen')),
            ],
          ),
        ),
      );
    }
    final device = _device!;
    final status = device.latestStatus;
    final isActiveHere = _activeDeviceId == device.id;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          device.name,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(device.model, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (isActiveHere) ...[
          const SizedBox(height: 12),
          Chip(
            avatar: Icon(Icons.phone_android, size: 18, color: theme.colorScheme.primary),
            label: Text(l10n.deviceActiveOnPhone),
          ),
        ],
        const SizedBox(height: 24),
        _Section(title: l10n.deviceSectionStatus, children: [
          if (device.lastSeenAt != null)
            _InfoRow(label: l10n.deviceLastSeen, value: formatRelativeTimeDe(device.lastSeenAt!))
          else
            _InfoRow(label: l10n.deviceLastSeen, value: l10n.deviceNeverSeen),
          if (status != null) ...[
            _InfoRow(
              label: l10n.deviceBattery,
              value: status.batteryPercent != null ? '${status.batteryPercent} %' : '—',
            ),
            _InfoRow(
              label: l10n.deviceLiquid,
              value: status.liquidPercent != null ? '${status.liquidPercent} %' : '—',
            ),
            if (status.isCharging != null)
              _InfoRow(
                label: l10n.deviceCharging,
                value: status.isCharging! ? l10n.deviceChargingYes : l10n.deviceChargingNo,
              ),
            if (status.firmwareVersion != null && status.firmwareVersion!.isNotEmpty)
              _InfoRow(label: l10n.deviceFirmware, value: status.firmwareVersion!),
            _InfoRow(
              label: l10n.deviceStatusRecorded,
              value: formatRelativeTimeDe(status.recordedAt),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.deviceNoStatusYet,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        _Section(title: l10n.deviceSectionInfo, children: [
          _InfoRow(
            label: l10n.deviceRegistered,
            value: DateFormat('d. MMM yyyy', 'de_DE').format(device.createdAt.toLocal()),
          ),
          if (device.firmwareVersion != null && device.firmwareVersion!.isNotEmpty)
            _InfoRow(label: l10n.deviceFirmwareReported, value: device.firmwareVersion!),
          _InfoRow(
            label: l10n.deviceHardwareId,
            value: device.hardwareId,
            monospace: true,
          ),
        ]),
        const SizedBox(height: 32),
        Text(l10n.deviceDeleteConfirm, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _deleting ? null : _confirmDelete,
          icon: _deleting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.delete_outline),
          label: Text(l10n.deviceDeleteAction),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.monospace = false});

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: monospace ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace') : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
