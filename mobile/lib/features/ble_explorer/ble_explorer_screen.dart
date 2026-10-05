import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/native/vapen_native.g.dart';
import '../../l10n/app_localizations.dart';
import '../../data/native/tracking_bridge.dart';

class BleExplorerScreen extends ConsumerStatefulWidget {
  const BleExplorerScreen({super.key});

  @override
  ConsumerState<BleExplorerScreen> createState() => _BleExplorerScreenState();
}

class _BleExplorerScreenState extends ConsumerState<BleExplorerScreen> {
  final _marker = TextEditingController();
  bool _scanning = false;

  @override
  void dispose() {
    _marker.dispose();
    super.dispose();
  }

  Future<bool> _ensureBlePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final ok = statuses.values.every((s) => s.isGranted);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bluetooth- und Standort-Berechtigung nötig (Standort nur für BLE-Scan unter Android 11).',
          ),
        ),
      );
    }
    return ok;
  }

  Future<void> _startScan(TrackingBridge bridge) async {
    if (!await _ensureBlePermissions()) return;
    bridge.explorerEvents.value = [];
    setState(() => _scanning = true);
    bridge.host.explorerStartScan(ExplorerScanFilter());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan läuft — Elfbar einschalten (Display an), 1–2 m Abstand.')),
    );
  }

  void _stopScan(TrackingBridge bridge) {
    bridge.host.explorerStopScan();
    setState(() => _scanning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan beendet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bridge = ref.watch(trackingBridgeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bleExplorerTitle),
        actions: [
          IconButton(
            onPressed: () async {
              final path = await bridge.host.explorerExportLog();
              await Share.shareXFiles([XFile(path)]);
            },
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _scanning
                      ? OutlinedButton.icon(
                          onPressed: () => _stopScan(bridge),
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Stop'),
                        )
                      : FilledButton.icon(
                          onPressed: () => _startScan(bridge),
                          icon: const Icon(Icons.radar_rounded),
                          label: const Text('Scan starten'),
                        ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _marker,
              decoration: InputDecoration(
                hintText: 'Marker-Notiz',
                prefixIcon: const Icon(Icons.bookmark_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Marker setzen',
                  onPressed: () {
                    if (_marker.text.isNotEmpty) {
                      bridge.host.explorerAddMarker(_marker.text);
                      _marker.clear();
                    }
                  },
                  icon: const Icon(Icons.bookmark_add_rounded),
                ),
              ),
            ),
          ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(),
            ),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder<List<ExplorerEvent>>(
              valueListenable: bridge.explorerEvents,
              builder: (context, events, _) {
                if (events.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _scanning
                            ? 'Warte auf BLE-Geräte… (Fernseher o. Ä. zeigt, dass der Scan grundsätzlich funktioniert.)'
                            : 'Scan starten, um Geräte in der Nähe zu sehen.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, i) {
                    final e = events[i];
                    return ListTile(
                      dense: true,
                      title: Text('${e.direction.name} ${e.note ?? ''}'),
                      subtitle: Text(e.hex.isNotEmpty ? e.hex : '—'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
