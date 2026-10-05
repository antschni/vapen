import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/duration_format.dart';
import '../../core/ui/widgets.dart';
import '../../core/vapen_logo.dart';
import '../../data/api/api_providers.dart';
import '../../data/auth/session_notifier.dart';
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
  UsageTotals? _today;
  UsageStats? _week;
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

  Future<void> _refresh() async {
    await _syncTrackingState();
    await _loadStats();
  }

  Future<void> _loadStats() async {
    final api = ref.read(apiClientProvider);
    final now = DateTime.now().toUtc();
    final tz = (await FlutterTimezone.getLocalTimezone()).identifier;
    final localNow = now.toLocal();
    final startOfToday = DateTime(localNow.year, localNow.month, localNow.day);
    try {
      final results = await Future.wait([
        api.getUsageStats(from: startOfToday.toUtc(), to: now, bucket: 'day', tz: tz),
        api.getUsageStats(
          from: startOfToday.subtract(const Duration(days: 6)).toUtc(),
          to: now,
          bucket: 'day',
          tz: tz,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _today = results[0].totals;
        _week = results[1];
        _statsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statsLoaded = true);
    }
  }

  int _displayTodayPuffs(TrackingState? state) {
    final local = state?.todayPuffCount?.toInt() ?? 0;
    final api = _today?.puffCount;
    if (api == null) return local;
    return api > local ? api : local;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bridge = ref.watch(trackingBridgeProvider);
    final name = ref.watch(sessionProvider.select((s) => s.user?.displayName));
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: [
            const VapenLogo(size: 36),
            const SizedBox(width: 12),
            Expanded(child: _Greeting(name: name)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ValueListenableBuilder<TrackingState?>(
        valueListenable: bridge.trackingState,
        builder: (context, state, _) {
          final enabled = state?.enabled ?? false;
          final pending = state?.pendingUploads?.toInt() ?? 0;
          final displayPuffs = _displayTodayPuffs(state);
          final syncHint = _syncHint(
            displayPuffs: displayPuffs,
            apiPuffs: _today?.puffCount,
            pending: pending,
          );
          final lastError = state?.lastError;

          final banners = <Widget>[
            if (pending > 0)
              InfoBanner(icon: Icons.cloud_upload_outlined, text: l10n.pendingUploads(pending)),
            if (syncHint != null)
              InfoBanner(icon: Icons.sync_rounded, text: syncHint, tone: BannerTone.neutral),
            if (lastError != null && lastError.isNotEmpty)
              InfoBanner(icon: Icons.error_outline_rounded, text: lastError, tone: BannerTone.error),
          ];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _TodayHeroCard(
                  puffCount: displayPuffs,
                  totals: _today,
                  statsLoaded: _statsLoaded,
                ),
                for (final banner in banners) ...[
                  const SizedBox(height: 12),
                  banner,
                ],
                const SectionHeader('Gerät'),
                _DeviceCard(
                  state: state,
                  connectionLabel: _connectionLabel(l10n, state?.connectionState),
                  enabled: enabled,
                  l10n: l10n,
                  onTrackingChanged: (v) {
                    if (v) {
                      bridge.host.startTracking();
                    } else {
                      bridge.host.stopTracking();
                    }
                  },
                ),
                SectionHeader(
                  'Letzte 7 Tage',
                  trailing: TextButton(
                    onPressed: () => context.go('/stats'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Statistik'),
                  ),
                  padding: const EdgeInsets.fromLTRB(4, 16, 0, 4),
                ),
                _WeekCard(
                  stats: _week,
                  loaded: _statsLoaded,
                  todayPuffs: displayPuffs,
                  onTap: () => context.go('/stats'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _syncHint({
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final salutation = hour < 11
        ? 'Guten Morgen'
        : hour < 18
            ? 'Hallo'
            : 'Guten Abend';
    final first = name?.trim().split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          first == null || first.isEmpty ? salutation : '$salutation, $first',
          style: theme.textTheme.titleLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          DateFormat('EEEE, d. MMMM', 'de').format(DateTime.now()),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({
    required this.puffCount,
    required this.totals,
    required this.statsLoaded,
  });

  final int puffCount;
  final UsageTotals? totals;
  final bool statsLoaded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onPrimary;
    final durationMs = totals?.totalDurationMs ?? 0;
    final avgMs = totals?.avgDurationMs ?? 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.55)!],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: _Bubble(size: 140, color: fg.withValues(alpha: 0.08)),
          ),
          Positioned(
            right: 50,
            bottom: -40,
            child: _Bubble(size: 90, color: fg.withValues(alpha: 0.06)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.today_rounded, size: 18, color: fg.withValues(alpha: 0.85)),
                    const SizedBox(width: 8),
                    Text(
                      'Heute',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: fg.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: !statsLoaded
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _homeCountFormat.format(puffCount),
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: fg,
                                height: 1.0,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              puffCount == 1 ? 'Zug' : 'Züge',
                              style: theme.textTheme.titleMedium?.copyWith(color: fg.withValues(alpha: 0.9)),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        icon: Icons.timer_outlined,
                        label: 'Gesamtdauer',
                        value: durationMs > 0 ? formatDurationMs(durationMs) : '—',
                        color: fg,
                      ),
                    ),
                    Container(width: 1, height: 32, color: fg.withValues(alpha: 0.2)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _HeroMetric(
                        icon: Icons.av_timer_rounded,
                        label: 'Ø pro Zug',
                        value: avgMs > 0 ? formatDurationMs(avgMs) : '—',
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.state,
    required this.connectionLabel,
    required this.enabled,
    required this.l10n,
    required this.onTrackingChanged,
  });

  final TrackingState? state;
  final String connectionLabel;
  final bool enabled;
  final AppLocalizations l10n;
  final ValueChanged<bool> onTrackingChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = state;
    final (Color dot, IconData icon) = _connectionVisual(s?.connectionState, scheme);
    final hasMetrics = s?.batteryPercent != null || s?.liquidPercent != null;
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                IconBadge(icon: icon, color: dot, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Elfbar Master', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _PulseDot(color: dot, pulsing: s?.connectionState == TrackingConnectionState.live),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              connectionLabel,
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (s?.simulationEnabled == true)
                  Chip(
                    label: const Text('Simulation'),
                    visualDensity: VisualDensity.compact,
                    labelStyle: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          if (hasMetrics)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(
                children: [
                  if (s!.batteryPercent != null)
                    Expanded(
                      child: _MetricBar(
                        icon: s.isCharging == true
                            ? Icons.battery_charging_full_rounded
                            : Icons.battery_std_rounded,
                        label: s.isCharging == true ? 'Akku · lädt' : 'Akku',
                        value: s.batteryPercent!.toInt(),
                      ),
                    ),
                  if (s.batteryPercent != null && s.liquidPercent != null) const SizedBox(width: 16),
                  if (s.liquidPercent != null)
                    Expanded(
                      child: _MetricBar(
                        icon: Icons.water_drop_rounded,
                        label: 'Liquid',
                        value: s.liquidPercent!.toInt(),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Divider(indent: 16, endIndent: 16),
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
            title: Text(enabled ? l10n.trackingEnabled : l10n.trackingDisabled),
            subtitle: Text(
              enabled ? 'Elfbar wird im Hintergrund ausgelesen' : 'Kein Bluetooth im Hintergrund',
            ),
            secondary: Icon(
              enabled ? Icons.sensors_rounded : Icons.sensors_off_rounded,
              color: enabled ? scheme.primary : scheme.onSurfaceVariant,
            ),
            value: enabled,
            onChanged: onTrackingChanged,
          ),
        ],
      ),
    );
  }

  (Color, IconData) _connectionVisual(TrackingConnectionState? s, ColorScheme scheme) {
    switch (s) {
      case TrackingConnectionState.live:
        return (scheme.primary, Icons.bluetooth_connected_rounded);
      case TrackingConnectionState.waiting:
      case TrackingConnectionState.disconnected:
        return (scheme.outline, Icons.bluetooth_disabled_rounded);
      case TrackingConnectionState.connecting:
      case TrackingConnectionState.discovering:
      case TrackingConnectionState.initializing:
        return (scheme.tertiary, Icons.bluetooth_searching_rounded);
      case TrackingConnectionState.idle:
      case null:
        return (scheme.outline, Icons.bluetooth_rounded);
    }
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulsing)
                Container(
                  width: 8 + 6 * t,
                  height: 8 + 6 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                  ),
                ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clamped = value.clamp(0, 100);
    final low = clamped <= 15;
    final color = low ? scheme.error : scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$clamped %',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 8,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.stats,
    required this.loaded,
    required this.todayPuffs,
    required this.onTap,
  });

  final UsageStats? stats;
  final bool loaded;
  final int todayPuffs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final counts = <int>[];
    for (final day in days) {
      var count = 0;
      for (final p in stats?.series ?? const <UsageSeriesPoint>[]) {
        final local = p.bucketStart.toLocal();
        if (local.year == day.year && local.month == day.month && local.day == day.day) {
          count = p.puffCount;
          break;
        }
      }
      if (day == today && todayPuffs > count) count = todayPuffs;
      counts.add(count);
    }
    final total = counts.fold<int>(0, (a, b) => a + b);
    final max = counts.fold<int>(0, (m, c) => c > m ? c : m);
    final avg = total / 7;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loaded ? _homeCountFormat.format(total) : '—',
                          style: theme.textTheme.headlineSmall,
                        ),
                        Text(
                          'Züge gesamt',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        loaded ? NumberFormat('#,##0.#', 'de_DE').format(avg) : '—',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Ø pro Tag',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _DayBar(
                            fraction: max == 0 ? 0 : counts[i] / max,
                            count: counts[i],
                            label: DateFormat('E', 'de').format(days[i]).substring(0, 2),
                            highlighted: i == 6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.fraction,
    required this.count,
    required this.label,
    required this.highlighted,
  });

  final double fraction;
  final int count;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = (constraints.maxHeight * fraction).clamp(4.0, constraints.maxHeight);
              return Align(
                alignment: Alignment.bottomCenter,
                child: Tooltip(
                  message: '$count Züge',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: h,
                    decoration: BoxDecoration(
                      color: highlighted ? scheme.primary : scheme.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
