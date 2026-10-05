import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/ui/widgets.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _groups == null;
      _error = null;
    });
    try {
      final groups = await ref.read(apiClientProvider).listGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
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

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
      );
    }
  }

  Future<void> _createGroup() async {
    final name = await _prompt(
      title: 'Neue Gruppe',
      label: 'Gruppenname',
      icon: Icons.group_add_outlined,
      confirm: 'Erstellen',
    );
    if (name == null || name.isEmpty) return;
    await _run(() => ref.read(apiClientProvider).createGroup(name));
  }

  Future<void> _joinByCode() async {
    final code = await _prompt(
      title: 'Gruppe beitreten',
      label: 'Einladungscode',
      icon: Icons.key_rounded,
      confirm: 'Beitreten',
      maxLength: 10,
    );
    if (code == null || code.length != 10) return;
    await _run(() => ref.read(apiClientProvider).joinGroup(code));
  }

  Future<void> _scanQr() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('QR-Code scannen', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Halte die Kamera auf den Einladungs-QR-Code.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 320,
                child: MobileScanner(
                  onDetect: (capture) {
                    final raw = capture.barcodes.firstOrNull?.rawValue;
                    if (raw == null) return;
                    final uri = Uri.tryParse(raw);
                    final code = uri?.pathSegments.lastOrNull;
                    if (code != null && code.length == 10) {
                      Navigator.pop(ctx);
                      _run(() => ref.read(apiClientProvider).joinGroup(code));
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSheet() async {
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NavTile(
                icon: Icons.group_add_outlined,
                title: 'Neue Gruppe erstellen',
                subtitle: 'Lade danach Freunde per Code oder QR ein',
                onTap: () => Navigator.pop(ctx, _createGroup),
                trailing: const SizedBox.shrink(),
              ),
              NavTile(
                icon: Icons.key_rounded,
                title: 'Mit Code beitreten',
                subtitle: '10-stelliger Einladungscode',
                color: Theme.of(ctx).colorScheme.secondary,
                onTap: () => Navigator.pop(ctx, _joinByCode),
                trailing: const SizedBox.shrink(),
              ),
              NavTile(
                icon: Icons.qr_code_scanner_rounded,
                title: 'QR-Code scannen',
                subtitle: 'Einladung direkt mit der Kamera öffnen',
                color: Theme.of(ctx).colorScheme.tertiary,
                onTap: () => Navigator.pop(ctx, _scanQr),
                trailing: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = _groups ?? const <GroupSummary>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupsTitle),
        actions: [
          IconButton(
            tooltip: 'QR-Code scannen',
            onPressed: _scanQr,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: groups.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Gruppe'),
            ),
      body: _buildBody(l10n, groups),
    );
  }

  Widget _buildBody(AppLocalizations l10n, List<GroupSummary> groups) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyState(
                icon: Icons.groups_rounded,
                title: 'Noch keine Gruppen',
                message: 'Erstelle eine Gruppe oder tritt mit einem Einladungscode bei, '
                    'um Live-Status und Rangliste mit Freunden zu teilen.',
                action: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: _createGroup,
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Gruppe erstellen'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _joinByCode,
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('Mit Code beitreten'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _GroupCard(
          group: groups[i],
          roleLabel: _roleLabel(l10n, groups[i].role),
          onTap: () async {
            await context.push('/groups/${groups[i].id}');
            if (mounted) _load();
          },
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, String role) => switch (role) {
        'owner' => l10n.groupRoleOwner,
        'admin' => l10n.groupRoleAdmin,
        _ => l10n.groupRoleMember,
      };

  Future<String?> _prompt({
    required String title,
    required String label,
    required IconData icon,
    required String confirm,
    int? maxLength,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          textCapitalization: maxLength == null ? TextCapitalization.sentences : TextCapitalization.none,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.roleLabel, required this.onTap});

  final GroupSummary group;
  final String roleLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOwner = group.role == 'owner';
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              InitialAvatar(name: group.name, radius: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people_alt_outlined, size: 15, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          group.memberCount == 1 ? '1 Mitglied' : '${group.memberCount} Mitglieder',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOwner ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  roleLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isOwner ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
