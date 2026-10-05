import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

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
    await requestBluetoothPermissions();
    await [
      Permission.notification,
      Permission.locationWhenInUse,
    ].request();
    await ref.read(requiredPermissionsProvider.notifier).refresh();
    if (context.mounted) context.go('/pairing');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bridge = ref.watch(trackingBridgeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.permissionsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.permissionsBluetooth),
          const SizedBox(height: 12),
          Text(l10n.permissionsNotifications),
          const SizedBox(height: 12),
          Text(l10n.permissionsBattery),
          const SizedBox(height: 8),
          const Text(
            'Tipp: Samsung/Xiaomi/Huawei — Akku-Optimierung deaktivieren (dontkillmyapp.com).',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => bridge.host.requestIgnoreBatteryOptimizations(),
            child: const Text('Batterie-Optimierung anfragen'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _requestAll(context),
            child: Text(l10n.continueButton),
          ),
        ],
      ),
    );
  }
}
