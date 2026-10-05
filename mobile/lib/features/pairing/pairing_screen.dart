import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/ui/widgets.dart';
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
      await ref.read(tokenStorageProvider).saveActiveDeviceId(device.id);
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AuthScaffold(
      title: l10n.pairDeviceTitle,
      subtitle: l10n.pairDeviceHint,
      showLogo: false,
      children: [
        Center(child: _PairingIllustration(active: _busy)),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final (i, step) in const [
                  'Elfbar einschalten (Display an) und in die Nähe halten',
                  'Auf „Suchen & koppeln“ tippen',
                  'Elfbar Master in der Systemliste auswählen',
                ].indexed)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(step, style: theme.textTheme.bodyMedium),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            secondary: IconBadge(icon: Icons.science_outlined, color: scheme.outline, size: 36),
            title: Text(l10n.simulatedDevice),
            subtitle: const Text('Zum Ausprobieren ohne echte Elfbar'),
            value: _useSimulation,
            onChanged: _busy ? null : (v) => setState(() => _useSimulation = v),
          ),
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 24),
        LoadingButton(
          label: l10n.pairDeviceButton,
          icon: Icons.bluetooth_searching_rounded,
          loading: _busy,
          onPressed: _pair,
        ),
      ],
    );
  }
}

class _PairingIllustration extends StatefulWidget {
  const _PairingIllustration({required this.active});

  final bool active;

  @override
  State<_PairingIllustration> createState() => _PairingIllustrationState();
}

class _PairingIllustrationState extends State<_PairingIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 150,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final offset in const [0.0, 0.5])
                Builder(
                  builder: (context) {
                    final t = (_controller.value + offset) % 1.0;
                    final speed = widget.active ? 1.0 : 0.6;
                    return Container(
                      width: 70 + 80 * t,
                      height: 70 + 80 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.18 * (1 - t) * speed),
                      ),
                    );
                  },
                ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                child: Icon(Icons.bluetooth_searching_rounded, size: 36, color: scheme.onPrimary),
              ),
            ],
          );
        },
      ),
    );
  }
}
