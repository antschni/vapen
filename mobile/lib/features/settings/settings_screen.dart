import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/widgets.dart';
import '../../data/auth/session_notifier.dart';
import '../../data/native/vapen_native.g.dart';
import '../../l10n/app_localizations.dart';
import '../../data/native/tracking_bridge.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _developer = false;

  Future<void> _confirmLogout(AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: Text(l10n.logoutButton),
        content: const Text('Möchtest du dich wirklich abmelden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: Text(l10n.logoutButton),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider);
    final bridge = ref.watch(trackingBridgeProvider);
    final scheme = Theme.of(context).colorScheme;
    final user = session.user;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _ProfileCard(
            name: user?.displayName ?? '',
            email: user?.email ?? '',
            onTap: () => context.push('/more/account'),
          ),
          const SectionHeader('Konto'),
          GroupedCard(
            children: [
              NavTile(
                icon: Icons.person_outline_rounded,
                title: 'Profil & Passwort',
                subtitle: 'Anzeigename, Passwort ändern',
                onTap: () => context.push('/more/account'),
              ),
              NavTile(
                icon: Icons.shield_outlined,
                title: l10n.privacyTitle,
                subtitle: 'Was Gruppen von dir sehen',
                color: scheme.tertiary,
                onTap: () => context.push('/more/privacy'),
              ),
            ],
          ),
          SectionHeader(l10n.devicesTitle),
          GroupedCard(
            children: [
              NavTile(
                icon: Icons.vaping_rooms_outlined,
                title: l10n.devicesTitle,
                subtitle: 'Gekoppelte Elfbars verwalten',
                onTap: () => context.push('/more/devices'),
              ),
              NavTile(
                icon: Icons.bluetooth_searching_rounded,
                title: l10n.pairDeviceTitle,
                subtitle: 'Neue Elfbar hinzufügen',
                color: scheme.secondary,
                onTap: () => context.push('/pairing'),
              ),
              NavTile(
                icon: Icons.battery_saver_outlined,
                title: 'Akku-Optimierung',
                subtitle: 'Hintergrund-Tracking zuverlässig halten',
                color: scheme.secondary,
                onTap: () => bridge.host.requestIgnoreBatteryOptimizations(),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              ),
            ],
          ),
          const SectionHeader('Verbindung'),
          GroupedCard(
            children: [
              NavTile(
                icon: Icons.dns_outlined,
                title: l10n.serverEndpointTitle,
                subtitle: session.baseUrl ?? '',
                color: scheme.secondary,
                onTap: () => context.push('/server'),
              ),
            ],
          ),
          const SectionHeader('Erweitert'),
          GroupedCard(
            children: [
              SwitchListTile(
                secondary: IconBadge(icon: Icons.code_rounded, color: scheme.outline, size: 36),
                title: Text(l10n.developerMode),
                value: _developer,
                onChanged: (v) => setState(() => _developer = v),
              ),
              if (_developer) ...[
                ValueListenableBuilder<TrackingState?>(
                  valueListenable: bridge.trackingState,
                  builder: (context, state, _) => SwitchListTile(
                    secondary: IconBadge(icon: Icons.science_outlined, color: scheme.outline, size: 36),
                    title: Text(l10n.simulatedDevice),
                    subtitle: const Text('Fake-Züge ohne echte Elfbar'),
                    value: state?.simulationEnabled ?? false,
                    onChanged: (v) => bridge.host.setSimulationEnabled(v),
                  ),
                ),
                NavTile(
                  icon: Icons.radar_rounded,
                  title: l10n.bleExplorerTitle,
                  subtitle: 'BLE-Verkehr mitschneiden',
                  color: scheme.outline,
                  onTap: () => context.push('/more/explorer'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(l10n),
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.logoutButton),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.email, required this.onTap});

  final String name;
  final String email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              InitialAvatar(name: name.isNotEmpty ? name : email, radius: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : '—',
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
