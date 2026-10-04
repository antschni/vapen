import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/duration_format.dart';
import '../../data/api/api_providers.dart';
import '../../data/native/vapen_native.g.dart';
import '../../l10n/app_localizations.dart';
import '../../data/native/tracking_bridge.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _todayPuffs;
  int? _todayDurationMs;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final api = ref.read(apiClientProvider);
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final stats = await api.getUsageStats(from: start, to: now, bucket: 'day');
    setState(() {
      _todayPuffs = stats.totals.puffCount;
      _todayDurationMs = stats.totals.totalDurationMs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bridge = ref.watch(trackingBridgeProvider);
    final state = bridge.trackingState.value;
    final enabled = state?.enabled ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: Text(enabled ? l10n.trackingEnabled : l10n.trackingDisabled),
              value: enabled,
              onChanged: (v) {
                if (v) {
                  bridge.host.startTracking();
                } else {
                  bridge.host.stopTracking();
                }
              },
            ),
            ListTile(
              title: const Text('Verbindung'),
              subtitle: Text(_connectionLabel(l10n, state?.connectionState)),
            ),
            if (state?.batteryPercent != null)
              ListTile(
                title: const Text('Batterie'),
                trailing: Text('${state!.batteryPercent} %'),
              ),
            if (state?.liquidPercent != null)
              ListTile(
                title: const Text('Liquid'),
                trailing: Text('${state!.liquidPercent} %'),
              ),
            ListTile(
              title: Text(l10n.todayPuffs(_todayPuffs ?? state?.todayPuffCount?.toInt() ?? 0)),
              subtitle: _todayDurationMs != null
                  ? Text('Gesamt: ${formatDurationMs(_todayDurationMs!)}')
                  : null,
            ),
            ListTile(
              title: Text(l10n.pendingUploads(state?.pendingUploads?.toInt() ?? 0)),
            ),
          ],
        ),
      ),
    );
  }

  String _connectionLabel(AppLocalizations l10n, TrackingConnectionState? s) {
    switch (s) {
      case TrackingConnectionState.live:
        return l10n.connectionLive;
      case TrackingConnectionState.waiting:
        return l10n.connectionWaiting;
      case TrackingConnectionState.disconnected:
        return l10n.connectionDisconnected;
      default:
        return s?.name ?? '—';
    }
  }
}
