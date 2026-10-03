import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../data/api/api_providers.dart';
import '../../l10n/app_localizations.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  List<GroupSummary>? _groups;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    final groups = await api.listGroups();
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _createGroup() async {
    final name = await _prompt(context, 'Gruppenname');
    if (name == null || name.isEmpty) return;
    await ref.read(apiClientProvider).createGroup(name);
    await _load();
  }

  Future<void> _joinByCode() async {
    final code = await _prompt(context, 'Einladungscode (10 Zeichen)');
    if (code == null || code.length != 10) return;
    await ref.read(apiClientProvider).joinGroup(code);
    await _load();
  }

  Future<void> _scanQr() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 320,
        child: MobileScanner(
          onDetect: (capture) {
            final raw = capture.barcodes.firstOrNull?.rawValue;
            if (raw == null) return;
            final uri = Uri.tryParse(raw);
            final code = uri?.pathSegments.last;
            if (code != null && code.length == 10) {
              Navigator.pop(ctx);
              ref.read(apiClientProvider).joinGroup(code).then((_) => _load());
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupsTitle),
        actions: [
          IconButton(onPressed: _scanQr, icon: const Icon(Icons.qr_code_scanner)),
          IconButton(onPressed: _joinByCode, icon: const Icon(Icons.vpn_key)),
          IconButton(onPressed: _createGroup, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _groups!.length,
                itemBuilder: (context, i) {
                  final g = _groups![i];
                  return ListTile(
                    title: Text(g.name),
                    subtitle: Text('${g.memberCount} Mitglieder · ${g.role}'),
                    onTap: () => context.push('/groups/${g.id}'),
                  );
                },
              ),
            ),
    );
  }

  Future<String?> _prompt(BuildContext context, String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }
}
