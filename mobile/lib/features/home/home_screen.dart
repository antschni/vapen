import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';

import '../../core/duration_format.dart';
import '../../core/vapen_logo.dart';
import '../../data/api/api_providers.dart';
import '../../data/native/vapen_native.g.dart';
import '../../l10n/app_localizations.dart';
import '../../data/native/tracking_bridge.dart';

final _homeCountFormat = NumberFormat.decimalPattern('de_DE');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _todayPuffs;
  int? _todayDurationMs;
  bool _statsLoaded = false;

  TrackingBridge? _bridge;

  @override
  void initState() {
    super.initState();
    _loadStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bridge = ref.read(trackingBridgeProvider);
      _bridge!.trackingState.addListener(_onTrackingStateChanged);
      _syncTrackingState();
    });
  }

  @override
  void dispose() {
    _bridge?.trackingState.removeListener(_onTrackingStateChanged);
    super.dispose();
  }

  void _onTrackingStateChanged() {
    final pending = _bridge?.trackingState.value?.pendingUploads ?? 0;
    if (pending == 0 && _statsLoaded) {
      _loadStats();
    }
  }

  Future<void> _syncTrackingState() async {
    final bridge = ref.read(trackingBridgeProvider);
    try {
      final state = await bridge.host.getTrackingState();
      bridge.onTrackingStateChanged(state);
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    final api = ref.read(apiClientProvider);
    final now = DateTime.now().toUtc();
    final tz = await FlutterTimezone.getLocalTimezone();
    final localNow = now.toLocal();
    final start = DateTime(localNow.year, localNow.month, localNow.day).toUtc();
    try {
      final stats = await api.getUsageStats(from: start, to: now, bucket: 'day', tz: tz);
      if (!mounted) return;
      setState(() {
        _todayPuffs = stats.totals.puffCount;
        _todayDurationMs = stats.totals.totalDurationMs;
        _statsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoaded = true);
    }
  }

  int _displayTodayPuffs(TrackingState? state) {
    final local = state?.todayPuffCount?.toInt() ?? 0;
    final api = _todayPuffs;
    if (api == null) return local;
    return api > local ? api : local;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bridge = ref.watch(trackingBridgeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const VapenLogo(size: 28),
            const SizedBox(width: 12),
            Text(l10n.homeTitle),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: () async {
              await _syncTrackingState();
              await _loadStats();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ValueListenableBuilder<TrackingState?>(
        valueListenable: bridge.trackingState,
        builder: (context, state, _) {
          final enabled = state?.enabled ?? false;
          final pending = state?.pendingUploads?.toInt() ?? 0;
          final displayPuffs = _displayTodayPuffs(state);
          final connection = state?.connectionState;
          final syncHint = _syncHint(
            context,
            displayPuffs: displayPuffs,
            apiPuffs: _todayPuffs,
            pending: pending,
          );

          return RefreshIndicator(
            onRefresh: () async {
              await _syncTrackingState();
              await _loadStats();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _TodayHeroCard(
                  puffCount: displayPuffs,
                  durationMs: _todayDurationMs,
                  statsLoaded: _statsLoaded,
                  l10n: l10n,
                ),
                const SizedBox(height: 16),
                _StatusRow(
                  connection: connection,
                  connectionLabel: _connectionLabel(l10n, connection),
                  enabled: enabled,
                  l10n: l10n,
                ),
                if (state?.batteryPercent != null || state?.liquidPercent != null) ...[
                  const SizedBox(height: 12),
                  _DeviceCard(state: state!),
                ],
                const SizedBox(height: 12),
                _TrackingCard(
                  enabled: enabled,
                  l10n: l10n,
                  onChanged: (v) {
                    if (v) {
                      bridge.host.startTracking();
                    } else {
                      bridge.host.stopTracking();
                    }
                  },
                ),
                if (pending > 0) ...[
                  const SizedBox(height: 12),
                  _InfoBanner(
                    icon: Icons.cloud_upload_outlined,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    foreground: Theme.of(context).colorScheme.onPrimaryContainer,
                    text: l10n.pendingUploads(pending),
                  ),
                ],
                if (syncHint != null) ...[
                  const SizedBox(height: 12),
                  _InfoBanner(
                    icon: Icons.sync_outlined,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    foreground: Theme.of(context).colorScheme.onSecondaryContainer,
                    text: syncHint,
                  ),
                ],
                if (state?.lastError != null && state!.lastError!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoBanner(
                    icon: Icons.error_outline,
                    color: Theme.of(context).colorScheme.errorContainer,
                    foreground: Theme.of(context).colorScheme.onErrorContainer,
                    text: state.lastError!,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String? _syncHint(
    BuildContext context, {
    required int displayPuffs,
    required int? apiPuffs,
    required int pending,
  }) {
    if (displayPuffs <= 0) return null;
    if ((apiPuffs ?? 0) == 0 && pending > 0) {
      return 'Züge am Gerät erkannt — $pending warten auf Upload';
    }
    if ((apiPuffs ?? 0) == 0 && pending == 0) {
      return 'Züge am Gerät — Server noch nicht synchronisiert (nach unten ziehen)';
    }
    return null;
  }

  String _connectionLabel(AppLocalizations l10n, TrackingConnectionState? s) {
    switch (s) {
      case TrackingConnectionState.live:
        return l10n.connectionLive;
      case TrackingConnectionState.waiting:
        return l10n.connectionWaiting;
      case TrackingConnectionState.disconnected:
        return l10n.connectionDisconnected;
      case TrackingConnectionState.connecting:
        return l10n.connectionConnecting;
      case TrackingConnectionState.discovering:
        return l10n.connectionDiscovering;
      case TrackingConnectionState.initializing:
        return l10n.connectionInitializing;
      case TrackingConnectionState.idle:
        return l10n.connectionIdle;
      case null:
        return '—';
    }
  }
}

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({
    required this.puffCount,
    required this.durationMs,
    required this.statsLoaded,
    required this.l10n,
  });

  final int puffCount;
  final int? durationMs;
  final bool statsLoaded;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heute',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            if (!statsLoaded)
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary),
                  ),
                ),
              )
            else
              Text(
                _homeCountFormat.format(puffCount),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                  height: 1.05,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Züge',
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.9)),
            ),
            if (durationMs != null && durationMs! > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: scheme.onPrimaryContainer.withValues(alpha: 0.75)),
                  const SizedBox(width: 6),
                  Text(
                    formatDurationMs(durationMs!),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    ' Gesamtdauer',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.connection,
    required this.connectionLabel,
    required this.enabled,
    required this.l10n,
  });

  final TrackingConnectionState? connection;
  final String connectionLabel;
  final bool enabled;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color dot, IconData icon) = _connectionVisual(connection, scheme);
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Icon(icon, size: 22, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verbindung', style: Theme.of(context).textTheme.labelMedium),
                        Text(connectionLabel, style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    enabled ? Icons.sensors : Icons.sensors_off,
                    size: 22,
                    color: enabled ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tracking', style: Theme.of(context).textTheme.labelMedium),
                        Text(
                          enabled ? l10n.trackingEnabled : l10n.trackingDisabled,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  (Color, IconData) _connectionVisual(TrackingConnectionState? s, ColorScheme scheme) {
    switch (s) {
      case TrackingConnectionState.live:
        return (scheme.primary, Icons.bluetooth_connected);
      case TrackingConnectionState.waiting:
      case TrackingConnectionState.disconnected:
        return (scheme.outline, Icons.bluetooth_disabled);
      case TrackingConnectionState.connecting:
      case TrackingConnectionState.discovering:
      case TrackingConnectionState.initializing:
        return (scheme.tertiary, Icons.bluetooth_searching);
      case TrackingConnectionState.idle:
      case null:
        return (scheme.outlineVariant, Icons.bluetooth);
    }
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.state});

  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gerät', style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
            if (state.batteryPercent != null)
              _MetricBar(
                icon: state.isCharging == true ? Icons.battery_charging_full : Icons.battery_std_outlined,
                label: 'Akku',
                value: state.batteryPercent!.toInt(),
                suffix: '%',
              ),
            if (state.batteryPercent != null && state.liquidPercent != null) const SizedBox(height: 14),
            if (state.liquidPercent != null)
              _MetricBar(
                icon: Icons.water_drop_outlined,
                label: 'Liquid',
                value: state.liquidPercent!.toInt(),
                suffix: '%',
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
  });

  final IconData icon;
  final String label;
  final int value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              '$clamped$suffix',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.enabled,
    required this.l10n,
    required this.onChanged,
  });

  final bool enabled;
  final AppLocalizations l10n;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        secondary: CircleAvatar(
          backgroundColor: enabled
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            enabled ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(enabled ? l10n.trackingEnabled : l10n.trackingDisabled),
        subtitle: Text(
          enabled ? 'Elfbar im Hintergrund auslesen' : 'Tracking pausiert — kein BLE im Hintergrund',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        value: enabled,
        onChanged: onChanged,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.foreground,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color foreground;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: foreground),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: foreground, height: 1.35))),
          ],
        ),
      ),
    );
  }
}
