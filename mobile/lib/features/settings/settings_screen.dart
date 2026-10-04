import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';
import '../../data/native/tracking_bridge.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _developer = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider);
    final bridge = ref.watch(trackingBridgeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            title: Text(session.user?.email ?? ''),
            subtitle: Text(session.user?.displayName ?? ''),
          ),
          ListTile(
            title: Text(l10n.serverEndpointTitle),
            subtitle: Text(session.baseUrl ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/server'),
          ),
          ListTile(
            title: const Text('Konto'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/more/account'),
          ),
          ListTile(
            title: const Text('Geräte'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/more/devices'),
          ),
          ListTile(
            title: const Text('Privatsphäre'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/more/privacy'),
          ),
          SwitchListTile(
            title: Text(l10n.developerMode),
            value: _developer,
            onChanged: (v) => setState(() => _developer = v),
          ),
          if (_developer) ...[
            SwitchListTile(
              title: Text(l10n.simulatedDevice),
              value: bridge.trackingState.value?.simulationEnabled ?? false,
              onChanged: (v) => bridge.host.setSimulationEnabled(v),
            ),
            ListTile(
              title: Text(l10n.bleExplorerTitle),
              onTap: () => context.push('/more/explorer'),
            ),
          ],
          ListTile(
            title: Text(l10n.logoutButton),
            onTap: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
