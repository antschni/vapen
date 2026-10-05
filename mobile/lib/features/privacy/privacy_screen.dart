import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/ui/widgets.dart';
import '../../data/api/api_providers.dart';
import '../../l10n/app_localizations.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  PrivacySettings? _settings;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await ref.read(apiClientProvider).getPrivacyDefaults();
      if (!mounted) return;
      setState(() {
        _settings = s;
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

  Future<void> _save(PrivacySettings s) async {
    final previous = _settings;
    setState(() => _settings = s);
    try {
      await ref.read(apiClientProvider).putPrivacyDefaults(s);
    } catch (_) {
      if (!mounted) return;
      setState(() => _settings = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
      );
    }
  }

  PrivacySettings _copy(
    PrivacySettings s, {
    bool? shareLiveStatus,
    bool? shareUsageSummary,
    bool? shareUsageDetail,
    bool? shareDeviceStats,
    bool? showInLeaderboard,
  }) {
    return PrivacySettings(
      shareLiveStatus: shareLiveStatus ?? s.shareLiveStatus,
      shareUsageSummary: shareUsageSummary ?? s.shareUsageSummary,
      shareUsageDetail: shareUsageDetail ?? s.shareUsageDetail,
      shareDeviceStats: shareDeviceStats ?? s.shareDeviceStats,
      showInLeaderboard: showInLeaderboard ?? s.showInLeaderboard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _settings == null) {
      return ErrorState(message: _error ?? AppLocalizations.of(context)!.genericError, onRetry: _load);
    }
    final s = _settings!;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const InfoBanner(
          icon: Icons.info_outline_rounded,
          tone: BannerTone.neutral,
          text: 'Standard für alle Gruppen. Änderungen werden sofort gespeichert.',
        ),
        const SectionHeader('Live'),
        GroupedCard(
          children: [
            _flag(
              icon: Icons.wifi_tethering_rounded,
              color: scheme.primary,
              title: 'Live-Status',
              subtitle: 'Andere sehen, ob du gerade dampfst, kürzlich aktiv warst oder inaktiv bist.',
              value: s.shareLiveStatus,
              onChanged: (v) => _save(_copy(s, shareLiveStatus: v)),
            ),
            _flag(
              icon: Icons.battery_5_bar_rounded,
              color: scheme.primary,
              title: 'Gerätestatus',
              subtitle: 'Akku, Liquid und Ladezustand deines Geräts.',
              value: s.shareDeviceStats,
              onChanged: (v) => _save(_copy(s, shareDeviceStats: v)),
            ),
          ],
        ),
        const SectionHeader('Nutzung'),
        GroupedCard(
          children: [
            _flag(
              icon: Icons.bar_chart_rounded,
              color: scheme.tertiary,
              title: 'Nutzungsübersicht',
              subtitle: 'Aggregierte Züge und Dampfzeit (z. B. tägliche Summen).',
              value: s.shareUsageSummary,
              onChanged: (v) => _save(_copy(s, shareUsageSummary: v)),
            ),
            _flag(
              icon: Icons.timeline_rounded,
              color: scheme.tertiary,
              title: 'Einzelzüge & Statistik',
              subtitle: 'Einzelne Züge mit Zeitstempel für detaillierte Auswertungen.',
              value: s.shareUsageDetail,
              onChanged: (v) => _save(_copy(s, shareUsageDetail: v)),
            ),
            _flag(
              icon: Icons.emoji_events_outlined,
              color: scheme.tertiary,
              title: 'In Rangliste',
              subtitle: 'Erscheine in Gruppen-Ranglisten (zusammen mit Nutzungsübersicht).',
              value: s.showInLeaderboard,
              onChanged: (v) => _save(_copy(s, showInLeaderboard: v)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _flag({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: IconBadge(icon: icon, color: value ? color : Theme.of(context).colorScheme.outline, size: 36),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
