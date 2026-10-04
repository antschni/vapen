import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

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
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: ValueListenableBuilder<TrackingState?>(
        valueListenable: bridge.trackingState,
        builder: (context, state, _) {
          final enabled = state?.enabled ?? false;
          final pending = state?.pendingUploads?.toInt() ?? 0;
          final displayPuffs = _displayTodayPuffs(state);
          return RefreshIndicator(
            onRefresh: () async {
              await _syncTrackingState();
              await _loadStats();
            },
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
                if (state?.lastError != null && state!.lastError!.isNotEmpty)
                  ListTile(
                    title: const Text('Hinweis'),
                    subtitle: Text(
                      state.lastError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
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
                  title: Text(l10n.todayPuffs(displayPuffs)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_todayDurationMs != null && _todayDurationMs! > 0)
                        Text('Gesamt (Server): ${formatDurationMs(_todayDurationMs!)}'),
                      if (displayPuffs > 0 && (_todayPuffs ?? 0) == 0 && pending > 0)
                        Text(
                          'Züge am Gerät erkannt — $pending warten auf Upload',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      if (displayPuffs > 0 && (_todayPuffs ?? 0) == 0 && pending == 0)
                        const Text('Züge am Gerät — Server noch nicht synchronisiert (nach unten ziehen)'),
                    ],
                  ),
                ),
                ListTile(
                  title: Text(l10n.pendingUploads(pending)),
                ),
              ],
            ),
          );
        },
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
