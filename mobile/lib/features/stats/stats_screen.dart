import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/duration_format.dart';
import '../../core/ui/widgets.dart';
import '../../data/api/api_providers.dart';
import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';

final _countFormat = NumberFormat.decimalPattern('de_DE');

enum _Range { week, month }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  UsageStats? _week;
  UsageStats? _month;
  bool _loading = true;
  String? _error;
  _Range _range = _Range.week;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final session = ref.read(sessionProvider);
    if (session.loading) {
      return;
    }
    if (!session.isAuthenticated) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.statsNotSignedIn;
        _week = null;
        _month = null;
      });
      return;
    }

    setState(() {
      _loading = _week == null;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final tz = await FlutterTimezone.getLocalTimezone();
      final nowLocal = DateTime.now();
      final now = nowLocal.toUtc();
      final startOfToday = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
      final weekFrom = startOfToday.subtract(const Duration(days: 6)).toUtc();
      final monthFrom = startOfToday.subtract(const Duration(days: 29)).toUtc();
      final results = await Future.wait([
        api.getUsageStats(from: weekFrom, to: now, bucket: 'day', tz: tz),
        api.getUsageStats(from: monthFrom, to: now, bucket: 'day', tz: tz),
      ]);
      if (!mounted) return;
      setState(() {
        _week = results[0];
        _month = results[1];
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(sessionProvider, (previous, next) {
      if (previous?.loading == true && !next.loading) {
        _load();
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
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
    final stats = _range == _Range.week ? _week : _month;
    if (stats == null) {
      return ErrorState(message: l10n.genericError, onRetry: _load);
    }
    final days = _range == _Range.week ? 7 : 30;
    final totals = stats.totals;
    final prev = stats.previousPeriod.puffCount;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SegmentedButton<_Range>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: _Range.week, label: Text(l10n.groupRange7d)),
              ButtonSegment(value: _Range.month, label: Text(l10n.groupRange30d)),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _StatTile(
                icon: Icons.cloud_outlined,
                label: 'Züge',
                value: _countFormat.format(totals.puffCount),
                trend: _trend(totals.puffCount, prev),
                highlighted: true,
              ),
              _StatTile(
                icon: Icons.timer_outlined,
                label: 'Gesamtdauer',
                value: totals.totalDurationMs > 0 ? formatDurationMs(totals.totalDurationMs) : '—',
              ),
              _StatTile(
                icon: Icons.av_timer_rounded,
                label: 'Ø pro Zug',
                value: totals.avgDurationMs > 0 ? formatDurationMs(totals.avgDurationMs) : '—',
              ),
              _StatTile(
                icon: Icons.event_available_outlined,
                label: 'Aktive Tage',
                value: '${totals.activeDays} / $days',
              ),
            ],
          ),
          const SectionHeader('Züge pro Tag'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
              child: SizedBox(
                height: 200,
                child: _BarChart(stats: stats, days: days),
              ),
            ),
          ),
          const SectionHeader('Tageszeit'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
              child: _Heatmap(stats: stats),
            ),
          ),
          if (totals.maxDurationMs > 0) ...[
            const SizedBox(height: 12),
            InfoBanner(
              icon: Icons.emoji_events_outlined,
              tone: BannerTone.neutral,
              text: 'Längster Zug im Zeitraum: ${formatDurationMs(totals.maxDurationMs)}',
            ),
          ],
        ],
      ),
    );
  }

  /// Change versus the previous period in percent, or null if not comparable.
  double? _trend(int current, int previous) {
    if (previous <= 0) return null;
    return (current - previous) / previous * 100;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trend,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? trend;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = highlighted ? scheme.onPrimaryContainer : scheme.onSurface;
    final muted = highlighted ? scheme.onPrimaryContainer.withValues(alpha: 0.75) : scheme.onSurfaceVariant;
    return Card(
      color: highlighted ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: muted)),
                ),
                if (trend != null) _TrendPill(trend: trend!),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.trend});

  final double trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Fewer puffs than before is the desirable direction.
    final down = trend <= 0;
    final color = down ? scheme.primary : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(down ? Icons.south_east_rounded : Icons.north_east_rounded, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '${trend.abs().round()} %',
            style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.stats});

  final UsageStats stats;

  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts = List.generate(7, (_) => List.filled(24, 0));
    var max = 0;
    for (final p in stats.heatmap) {
      if (p.isoWeekday < 1 || p.isoWeekday > 7 || p.hour < 0 || p.hour > 23) continue;
      counts[p.isoWeekday - 1][p.hour] = p.puffCount;
      if (p.puffCount > max) max = p.puffCount;
    }
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return Column(
      children: [
        for (var day = 0; day < 7; day++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(width: 24, child: Text(_weekdays[day], style: labelStyle)),
                for (var hour = 0; hour < 24; hour++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Tooltip(
                        message: '${_weekdays[day]} ${hour.toString().padLeft(2, '0')}:00 · ${counts[day][hour]} Züge',
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: counts[day][hour] == 0
                                  ? scheme.surfaceContainerHighest
                                  : scheme.primary.withValues(alpha: 0.2 + 0.8 * counts[day][hour] / max),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(width: 24),
            for (final h in const [0, 6, 12, 18])
              Expanded(child: Text('$h Uhr', style: labelStyle)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('weniger', style: labelStyle),
            const SizedBox(width: 6),
            for (final a in const [0.0, 0.25, 0.5, 0.75, 1.0])
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: a == 0 ? scheme.surfaceContainerHighest : scheme.primary.withValues(alpha: 0.2 + 0.8 * a),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 6),
            Text('mehr', style: labelStyle),
          ],
        ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.stats, required this.days});

  final UsageStats stats;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(days, (i) => today.subtract(Duration(days: days - 1 - i)));
    final points = <UsageSeriesPoint?>[];
    for (final d in dates) {
      UsageSeriesPoint? match;
      for (final p in stats.series) {
        final local = p.bucketStart.toLocal();
        if (local.year == d.year && local.month == d.month && local.day == d.day) {
          match = p;
          break;
        }
      }
      points.add(match);
    }
    final maxY = points.fold<int>(0, (m, p) => (p?.puffCount ?? 0) > m ? p!.puffCount : m);
    final barWidth = days <= 7 ? 22.0 : 6.0;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 5 : maxY * 1.15,
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (var i = 0; i < days; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (points[i]?.puffCount ?? 0).toDouble(),
                  color: i == days - 1 ? scheme.primary : scheme.primary.withValues(alpha: 0.55),
                  width: barWidth,
                  borderRadius: BorderRadius.circular(days <= 7 ? 6 : 3),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY == 0 ? 5 : maxY * 1.15,
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value % 1 != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(_countFormat.format(value.toInt()), style: labelStyle),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days) return const SizedBox.shrink();
                final d = dates[i];
                final String text;
                if (days <= 7) {
                  text = DateFormat('E', 'de').format(d).substring(0, 2);
                } else if ((days - 1 - i) % 7 == 0) {
                  text = DateFormat('d.M.', 'de').format(d);
                } else {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(meta: meta, child: Text(text, style: labelStyle));
              },
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = points[group.x];
              final date = DateFormat('EEE, d. MMM', 'de').format(dates[group.x]);
              final duration = (p?.totalDurationMs ?? 0) > 0 ? '\n${formatDurationMs(p!.totalDurationMs)}' : '';
              return BarTooltipItem(
                '$date\n',
                theme.textTheme.labelSmall!.copyWith(color: scheme.onInverseSurface.withValues(alpha: 0.8)),
                children: [
                  TextSpan(
                    text: '${p?.puffCount ?? 0} Züge$duration',
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
