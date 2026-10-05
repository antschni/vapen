import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../auth/session_notifier.dart';
import '../native/tracking_bridge.dart';
import '../permissions/required_permissions.dart';

/// True when this account already has a registered Elfbar, or this phone still has one paired.
Future<bool> accountHasDevice(WidgetRef ref) async {
  try {
    final devices = await ref.read(apiClientProvider).listDevices();
    if (devices.isNotEmpty) return true;
  } catch (_) {}
  final stored = await ref.read(tokenStorageProvider).readActiveDeviceId();
  if (stored != null && stored.isNotEmpty) return true;
  try {
    final native = await ref.read(trackingBridgeProvider).host.getActiveDeviceId();
    if (native != null && native.isNotEmpty) return true;
  } catch (_) {}
  return false;
}

/// Next screen after login or after the permission step.
Future<String> routeAfterAuth(WidgetRef ref) async {
  if (!await bluetoothPermissionsGranted()) return '/permissions';
  if (await accountHasDevice(ref)) return '/home';
  return '/pairing';
}
