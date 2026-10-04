import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../data/api/api_providers.dart';
import '../../data/auth/session_notifier.dart';
import '../../data/native/vapen_native.g.dart';
import '../../l10n/app_localizations.dart';
import '../../data/native/tracking_bridge.dart';

String hardwareIdFromBleAddress(String address) {
  final normalized = address.toLowerCase();
  final digest = sha256.convert(utf8.encode(normalized));
  return digest.toString();
}

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _busy = false;
  String? _error;
  bool _useSimulation = false;

  Future<void> _pair() async {
    final l10n = AppLocalizations.of(context)!;
    final bridge = ref.read(trackingBridgeProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String hardwareId;
      if (_useSimulation) {
        bridge.host.setSimulationEnabled(true);
        hardwareId = hardwareIdFromBleAddress('sim-${DateTime.now().millisecondsSinceEpoch}');
      } else {
        final result = await bridge.host.associateDevice();
        if (!result.success || result.address == null) {
          setState(() => _error = result.errorMessage ?? l10n.genericError);
          return;
        }
        hardwareId = hardwareIdFromBleAddress(result.address!);
        bridge.host.setSimulationEnabled(false);
      }
      final api = ref.read(apiClientProvider);
      final device = await api.createDevice(
        CreateDeviceRequest(model: 'elfbar_master', name: 'Meine Elfbar', hardwareId: hardwareId),
      );
      final token = await api.createIngestToken(device.id, 'Android Vapen');
      final baseUrl = ref.read(sessionProvider).baseUrl!;
      await bridge.host.setCredentials(
        NativeCredentials(
          baseUrl: baseUrl,
          deviceId: device.id,
          deviceToken: token.token,
          hardwareId: device.hardwareId,
        ),
      );
      await bridge.host.startTracking();
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString().contains('SocketException') || e.toString().contains('Connection')
          ? 'Server nicht erreichbar — URL und Netzwerk prüfen.'
          : l10n.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairDeviceTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.pairDeviceHint),
            SwitchListTile(
              title: Text(l10n.simulatedDevice),
              value: _useSimulation,
              onChanged: _busy ? null : (v) => setState(() => _useSimulation = v),
            ),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            FilledButton(
              onPressed: _busy ? null : _pair,
              child: _busy ? const CircularProgressIndicator() : Text(l10n.continueButton),
            ),
          ],
        ),
      ),
    );
  }
}
