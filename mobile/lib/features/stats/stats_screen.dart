import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../data/api/api_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    final now = DateTime.now().toUtc();
    final weekFrom = now.subtract(const Duration(days: 7));
    final monthFrom = now.subtract(const Duration(days: 30));
    final results = await Future.wait([
      api.getUsageStats(from: weekFrom, to: now, bucket: 'day'),
      api.getUsageStats(from: monthFrom, to: now, bucket: 'day'),
    ]);
    setState(() {
      _week = results[0];
      _month = results[1];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('7 Tage', style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 200, child: _BarChart(stats: _week!)),
                  const SizedBox(height: 24),
                  Text('30 Tage', style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 200, child: _BarChart(stats: _month!)),
                  const SizedBox(height: 24),
                  Text('Tageszeit (Heatmap)', style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 160, child: _Heatmap(stats: _week!)),
                ],
              ),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 24, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: 24 * 7,
      itemBuilder: (context, index) {
        final hour = index % 24;
        final day = index ~/ 24 + 1;
        final point = stats.heatmap.where((p) => p.isoWeekday == day && p.hour == hour).firstOrNull;
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
    final bars = stats.series
        .map(
          (p) => BarChartGroupData(
            x: stats.series.indexOf(p),
            barRods: [
              BarChartRodData(
                toY: p.totalDurationMs / 1000,
                color: Theme.of(context).colorScheme.primary,
                width: 8,
              ),
            ],
          ),
        )
        .toList();
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
