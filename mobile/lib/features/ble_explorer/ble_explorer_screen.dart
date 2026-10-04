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
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _marker,
                    decoration: const InputDecoration(hintText: 'Marker-Notiz'),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_marker.text.isNotEmpty) {
                      bridge.host.explorerAddMarker(_marker.text);
                      _marker.clear();
                    }
                  },
                  icon: const Icon(Icons.bookmark_add),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                onPressed: _scanning ? null : () => _startScan(bridge),
                child: Text(_scanning ? 'Scan…' : 'Scan'),
              ),
              FilledButton(
                onPressed: _scanning ? () => _stopScan(bridge) : null,
                child: const Text('Stop'),
              ),
            ],
          ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
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
