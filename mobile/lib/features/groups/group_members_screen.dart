import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../data/api/api_providers.dart';
import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';

class GroupMembersScreen extends ConsumerStatefulWidget {
  const GroupMembersScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends ConsumerState<GroupMembersScreen> {
  Group? _group;
  bool _loading = true;
  String? _error;
  bool _busy = false;

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
      final group = await ref.read(apiClientProvider).getGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        _group = group;
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

  String? get _myUserId => ref.read(sessionProvider).user?.id;

  String? _myRole(Group group) {
    final uid = _myUserId;
    if (uid == null) return null;
    for (final m in group.members) {
      if (m.userId == uid) return m.role;
    }
    return null;
  }

  String _roleLabel(AppLocalizations l10n, String role) {
    return switch (role) {
      'owner' => l10n.groupRoleOwner,
      'admin' => l10n.groupRoleAdmin,
      _ => l10n.groupRoleMember,
    };
  }

  Future<bool> _confirm(String title, String message) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } on VapenApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.problem.detail ?? e.problem.code)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setRole(GroupMember member, String role, AppLocalizations l10n) async {
    if (role == 'owner') {
      final ok = await _confirm(
        l10n.groupTransferOwnership,
        l10n.groupTransferOwnershipConfirm(member.displayName),
      );
      if (!ok || !mounted) return;
    }
    await _runAction(() => ref.read(apiClientProvider).patchGroupMember(widget.groupId, member.userId, role));
  }

  Future<void> _removeMember(GroupMember member, AppLocalizations l10n) async {
    final ok = await _confirm(
      l10n.groupRemoveMember,
      l10n.groupRemoveMemberConfirm(member.displayName),
    );
    if (!ok || !mounted) return;
    await _runAction(() async {
      await ref.read(apiClientProvider).removeGroupMember(widget.groupId, member.userId);
      if (member.userId == _myUserId && mounted) context.pop();
    });
  }

  Future<void> _leaveGroup(AppLocalizations l10n) async {
    final ok = await _confirm(l10n.groupLeave, l10n.groupLeaveConfirm);
    if (!ok || !mounted) return;
    await _runAction(() async {
      await ref.read(apiClientProvider).leaveGroup(widget.groupId);
      if (mounted) context.go('/groups');
    });
  }

  Future<void> _deleteGroup(AppLocalizations l10n) async {
    final ok = await _confirm(l10n.groupDelete, l10n.groupDeleteConfirm);
    if (!ok || !mounted) return;
    await _runAction(() async {
      await ref.read(apiClientProvider).deleteGroup(widget.groupId);
      if (mounted) context.go('/groups');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final group = _group;
    final myRole = group != null ? _myRole(group) : null;
    final isOwner = myRole == 'owner';
    final isAdmin = myRole == 'admin' || isOwner;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupMembersTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Erneut versuchen')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (group != null)
                        Text(
                          group.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      Text(
                        '${group?.memberCount ?? 0} ${l10n.groupMembersTitle.toLowerCase()}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      ...?group?.members.map((member) {
                        final canChangeRole = isOwner && member.role != 'owner';
                        final canRemove = isAdmin && member.role != 'owner' && !(member.role == 'admin' && !isOwner);
                        return _MemberTile(
                          member: member,
                          roleLabel: _roleLabel(l10n, member.role),
                          isSelf: member.userId == _myUserId,
                          busy: _busy,
                          canChangeRole: canChangeRole,
                          canRemove: canRemove,
                          onPromoteAdmin: member.role == 'member'
                              ? () => _setRole(member, 'admin', l10n)
                              : null,
                          onDemoteMember: member.role == 'admin'
                              ? () => _setRole(member, 'member', l10n)
                              : null,
                          onTransferOwnership: canChangeRole
                              ? () => _setRole(member, 'owner', l10n)
                              : null,
                          onRemove: canRemove ? () => _removeMember(member, l10n) : null,
                          l10n: l10n,
                        );
                      }),
                      const SizedBox(height: 24),
                      if (myRole != null && myRole != 'owner')
                        OutlinedButton(
                          onPressed: _busy ? null : () => _leaveGroup(l10n),
                          child: Text(l10n.groupLeave),
                        ),
                      if (isOwner) ...[
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _busy ? null : () => _deleteGroup(l10n),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          ),
                          child: Text(l10n.groupDelete),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.roleLabel,
    required this.isSelf,
    required this.busy,
    required this.canChangeRole,
    required this.canRemove,
    required this.l10n,
    this.onPromoteAdmin,
    this.onDemoteMember,
    this.onTransferOwnership,
    this.onRemove,
  });

  final GroupMember member;
  final String roleLabel;
  final bool isSelf;
  final bool busy;
  final bool canChangeRole;
  final bool canRemove;
  final AppLocalizations l10n;
  final VoidCallback? onPromoteAdmin;
  final VoidCallback? onDemoteMember;
  final VoidCallback? onTransferOwnership;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (isSelf)
                        Text(
                          'Du',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(roleLabel),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            if (canChangeRole || canRemove) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onPromoteAdmin != null)
                    OutlinedButton(
                      onPressed: busy ? null : onPromoteAdmin,
                      child: Text(l10n.groupPromoteAdmin),
                    ),
                  if (onDemoteMember != null)
                    OutlinedButton(
                      onPressed: busy ? null : onDemoteMember,
                      child: Text(l10n.groupDemoteMember),
                    ),
                  if (onTransferOwnership != null)
                    OutlinedButton(
                      onPressed: busy ? null : onTransferOwnership,
                      child: Text(l10n.groupTransferOwnership),
                    ),
                  if (onRemove != null)
                    TextButton(
                      onPressed: busy ? null : onRemove,
                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                      child: Text(l10n.groupRemoveMember),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
