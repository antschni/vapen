import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/ui/widgets.dart';
import '../../data/devices/account_devices.dart';
import '../../data/permissions/required_permissions.dart';
import '../../l10n/app_localizations.dart';
import '../../data/native/tracking_bridge.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  var _promptedBluetooth = false;
  var _continuing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptBluetoothIfNeeded());
  }

  Future<void> _promptBluetoothIfNeeded() async {
    if (_promptedBluetooth || !mounted) return;
    _promptedBluetooth = true;
    if (await bluetoothPermissionsGranted()) return;
    await requestBluetoothPermissions();
    await ref.read(requiredPermissionsProvider.notifier).refresh();
  }

  Future<void> _requestAll(BuildContext context) async {
    setState(() => _continuing = true);
    try {
      await requestBluetoothPermissions();
      await [
        Permission.notification,
        Permission.locationWhenInUse,
      ].request();
      await ref.read(requiredPermissionsProvider.notifier).refresh();
      if (!context.mounted) return;
      final hasDevice = await accountHasDevice(ref);
      if (context.mounted) context.go(hasDevice ? '/home' : '/pairing');
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bridge = ref.watch(trackingBridgeProvider);
    final scheme = Theme.of(context).colorScheme;
    return AuthScaffold(
      title: l10n.permissionsTitle,
      subtitle: 'Damit Vapen deine Elfbar zuverlässig im Hintergrund auslesen kann.',
      showLogo: false,
      children: [
        GroupedCard(
          children: [
            _PermissionTile(
              icon: Icons.bluetooth_rounded,
              color: scheme.primary,
              title: 'Bluetooth',
              text: l10n.permissionsBluetooth,
            ),
            _PermissionTile(
              icon: Icons.notifications_outlined,
              color: scheme.secondary,
              title: 'Benachrichtigungen',
              text: l10n.permissionsNotifications,
            ),
            _PermissionTile(
              icon: Icons.battery_saver_outlined,
              color: scheme.tertiary,
              title: 'Akku-Optimierung',
              text: l10n.permissionsBattery,
              action: TextButton(
                onPressed: () => bridge.host.requestIgnoreBatteryOptimizations(),
                child: const Text('Batterie-Optimierung anfragen'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const InfoBanner(
          icon: Icons.lightbulb_outline_rounded,
          tone: BannerTone.neutral,
          text: 'Tipp: Samsung/Xiaomi/Huawei — Akku-Optimierung deaktivieren (dontkillmyapp.com).',
        ),
        const SizedBox(height: 28),
        LoadingButton(
          label: l10n.continueButton,
          loading: _continuing,
          onPressed: () => _requestAll(context),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Transform.translate(offset: const Offset(-12, 0), child: action),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
