import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  Future<void> _requestAll(BuildContext context, WidgetRef ref) async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
      Permission.locationWhenInUse,
    ].request();
    if (context.mounted) context.go('/pairing');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onPressed: () => _requestAll(context, ref),
            child: Text(l10n.continueButton),
          ),
        ],
      ),
    );
  }
}
