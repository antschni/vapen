import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../data/api/api_providers.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  PrivacySettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final s = await api.getPrivacyDefaults();
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  Future<void> _save(PrivacySettings s) async {
    setState(() => _settings = s);
    await ref.read(apiClientProvider).putPrivacyDefaults(s);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = _settings!;
    return Scaffold(
      appBar: AppBar(title: const Text('Privatsphäre')),
      body: ListView(
        children: [
          _flag(
            'Live-Status teilen',
            'Andere sehen, ob du gerade dampfst.',
            s.shareLiveStatus,
            (v) => _save(PrivacySettings(
              shareLiveStatus: v,
              shareUsageSummary: s.shareUsageSummary,
              shareUsageDetail: s.shareUsageDetail,
              shareDeviceStats: s.shareDeviceStats,
              showInLeaderboard: s.showInLeaderboard,
            )),
          ),
          _flag(
            'Nutzungsübersicht teilen',
            'Tages- und Gesamtwerte in Gruppen.',
            s.shareUsageSummary,
            (v) => _save(PrivacySettings(
              shareLiveStatus: s.shareLiveStatus,
              shareUsageSummary: v,
              shareUsageDetail: s.shareUsageDetail,
              shareDeviceStats: s.shareDeviceStats,
              showInLeaderboard: s.showInLeaderboard,
            )),
          ),
          _flag(
            'Detaildaten teilen',
            'Einzelne Züge mit Zeitstempel.',
            s.shareUsageDetail,
            (v) => _save(PrivacySettings(
              shareLiveStatus: s.shareLiveStatus,
              shareUsageSummary: s.shareUsageSummary,
              shareUsageDetail: v,
              shareDeviceStats: s.shareDeviceStats,
              showInLeaderboard: s.showInLeaderboard,
            )),
          ),
        ],
      ),
    );
  }

  Widget _flag(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(title: Text(title), subtitle: Text(subtitle), value: value, onChanged: onChanged);
  }
}
