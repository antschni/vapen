import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void dispose() {
    _marker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bridge = ref.watch(trackingBridgeProvider);
    final events = bridge.explorerEvents.value;
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
                onPressed: () => bridge.host.explorerStartScan(ExplorerScanFilter()),
                child: const Text('Scan'),
              ),
              FilledButton(
                onPressed: () => bridge.host.explorerStopScan(),
                child: const Text('Stop'),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, i) {
                final e = events[i];
                return ListTile(
                  dense: true,
                  title: Text('${e.direction.name} ${e.note ?? ''}'),
                  subtitle: Text(e.hex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
