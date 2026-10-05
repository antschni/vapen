import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../data/api/api_providers.dart';
import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';

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
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final tz = await FlutterTimezone.getLocalTimezone();
      final now = DateTime.now().toUtc();
      final weekFrom = now.subtract(const Duration(days: 7));
      final monthFrom = now.subtract(const Duration(days: 30));
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
    final week = _week;
    final month = _month;
    if (week == null || month == null) {
      return Center(child: Text(l10n.genericError));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('7 Tage', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 200, child: _BarChart(stats: week)),
          const SizedBox(height: 24),
          Text('30 Tage', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 200, child: _BarChart(stats: month)),
          const SizedBox(height: 24),
          Text('Tageszeit (Heatmap)', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 160, child: _Heatmap(stats: week)),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.stats});

  final UsageStats stats;

  @override
  Widget build(BuildContext context) {
    final max = stats.heatmap.fold<int>(0, (m, p) => p.puffCount > m ? p.puffCount : m);
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 24, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: 24 * 7,
      itemBuilder: (context, index) {
        final hour = index % 24;
        final day = index ~/ 24 + 1;
        HeatmapPoint? point;
        for (final p in stats.heatmap) {
          if (p.isoWeekday == day && p.hour == hour) {
            point = p;
            break;
          }
        }
        final count = point?.puffCount ?? 0;
        final intensity = max == 0 ? 0.0 : count / max;
        return ColoredBox(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15 + intensity * 0.85),
        );
      },
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.stats});

  final UsageStats stats;

  @override
  Widget build(BuildContext context) {
    final bars = <BarChartGroupData>[];
    for (var i = 0; i < stats.series.length; i++) {
      final p = stats.series[i];
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: p.totalDurationMs / 1000,
              color: Theme.of(context).colorScheme.primary,
              width: 8,
            ),
          ],
        ),
      );
    }
    return BarChart(
      BarChartData(
        barGroups: bars,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
