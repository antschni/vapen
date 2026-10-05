import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class RequiredPermissionsState {
  const RequiredPermissionsState({this.loading = true, this.granted = false});

  final bool loading;
  final bool granted;
}

class RequiredPermissionsNotifier extends Notifier<RequiredPermissionsState> {
  @override
  RequiredPermissionsState build() {
    Future.microtask(refresh);
    return const RequiredPermissionsState(loading: true);
  }

  Future<void> refresh() async {
    if (!Platform.isAndroid) {
      state = const RequiredPermissionsState(loading: false, granted: true);
      return;
    }
    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    state = RequiredPermissionsState(
      loading: false,
      granted: scan.isGranted && connect.isGranted,
    );
  }
}

final requiredPermissionsProvider =
    NotifierProvider<RequiredPermissionsNotifier, RequiredPermissionsState>(
  RequiredPermissionsNotifier.new,
);

Future<bool> bluetoothPermissionsGranted() async {
  if (!Platform.isAndroid) return true;
  final scan = await Permission.bluetoothScan.status;
  final connect = await Permission.bluetoothConnect.status;
  return scan.isGranted && connect.isGranted;
}

Future<void> requestBluetoothPermissions() async {
  if (!Platform.isAndroid) return;
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ].request();
}
