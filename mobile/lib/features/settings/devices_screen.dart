import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../data/api/api_providers.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  List<Device>? _devices;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(apiClientProvider).listDevices();
    setState(() => _devices = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geräte')),
      body: _devices == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _devices!.length,
              itemBuilder: (context, i) {
                final d = _devices![i];
                final status = d.latestStatus;
                return ListTile(
                  title: Text(d.name),
                  subtitle: Text(
                    status != null
                        ? 'Batterie ${status.batteryPercent ?? "?"} % · Liquid ${status.liquidPercent ?? "?"} %'
                        : d.hardwareId,
                  ),
                );
              },
            ),
    );
  }
}
