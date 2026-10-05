import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/relative_time_format.dart';
import '../../data/api/api_providers.dart';
import '../../l10n/app_localizations.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  List<Device>? _devices;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(apiClientProvider).listDevices();
      if (!mounted) return;
      setState(() {
        _devices = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.genericError;
      });
    }
  }

  Future<void> _openDevice(Device device) async {
    final deleted = await context.push<bool>('/more/devices/${device.id}');
    if (deleted == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pairing'),
        icon: const Icon(Icons.bluetooth_connected),
        label: Text(l10n.pairDeviceTitle),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Erneut versuchen')),
            ],
          ),
        ),
      );
    }
    final devices = _devices ?? [];
    if (devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.devicesEmpty,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.devicesEmptyHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/pairing'),
                icon: const Icon(Icons.add),
                label: Text(l10n.pairDeviceTitle),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: devices.length,
        itemBuilder: (context, i) {
          final d = devices[i];
          final status = d.latestStatus;
          final subtitle = StringBuffer();
          if (d.lastSeenAt != null) {
            subtitle.write('${l10n.deviceLastSeen} ${formatRelativeTimeDe(d.lastSeenAt!)}');
          }
          if (status != null) {
            if (subtitle.isNotEmpty) subtitle.write(' · ');
            subtitle.write('Akku ${status.batteryPercent ?? "?"} %');
          }
          if (subtitle.isEmpty) subtitle.write(d.model);
          return ListTile(
            title: Text(d.name),
            subtitle: Text(subtitle.toString()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDevice(d),
          );
        },
      ),
    );
  }
}
