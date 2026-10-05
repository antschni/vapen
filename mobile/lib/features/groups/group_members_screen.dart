import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/ui/widgets.dart';
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

    final scheme = Theme.of(context).colorScheme;
    final members = [...?group?.members]..sort((a, b) {
        const order = {'owner': 0, 'admin': 1, 'member': 2};
        final byRole = (order[a.role] ?? 3).compareTo(order[b.role] ?? 3);
        return byRole != 0 ? byRole : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? l10n.groupMembersTitle),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    children: [
                      SectionHeader(
                        '${group?.memberCount ?? 0} ${l10n.groupMembersTitle}',
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                      ),
                      GroupedCard(
                        children: [
                          for (final member in members)
                            _MemberTile(
                              member: member,
                              roleLabel: _roleLabel(l10n, member.role),
                              isSelf: member.userId == _myUserId,
                              busy: _busy,
                              onPromoteAdmin: isOwner && member.role == 'member'
                                  ? () => _setRole(member, 'admin', l10n)
                                  : null,
                              onDemoteMember: isOwner && member.role == 'admin'
                                  ? () => _setRole(member, 'member', l10n)
                                  : null,
                              onTransferOwnership: isOwner && member.role != 'owner'
                                  ? () => _setRole(member, 'owner', l10n)
                                  : null,
                              onRemove: isAdmin &&
                                      member.role != 'owner' &&
                                      !(member.role == 'admin' && !isOwner)
                                  ? () => _removeMember(member, l10n)
                                  : null,
                              l10n: l10n,
                            ),
                        ],
                      ),
                      if (myRole != null) ...[
                        const SectionHeader('Gruppe'),
                        GroupedCard(
                          children: [
                            if (myRole != 'owner')
                              NavTile(
                                icon: Icons.logout_rounded,
                                title: l10n.groupLeave,
                                color: scheme.error,
                                onTap: _busy ? null : () => _leaveGroup(l10n),
                                trailing: const SizedBox.shrink(),
                              ),
                            if (isOwner)
                              NavTile(
                                icon: Icons.delete_forever_outlined,
                                title: l10n.groupDelete,
                                subtitle: 'Für alle Mitglieder, unwiderruflich',
                                color: scheme.error,
                                onTap: _busy ? null : () => _deleteGroup(l10n),
                                trailing: const SizedBox.shrink(),
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

enum _MemberAction { promote, demote, transfer, remove }

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.roleLabel,
    required this.isSelf,
    required this.busy,
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
  final AppLocalizations l10n;
  final VoidCallback? onPromoteAdmin;
  final VoidCallback? onDemoteMember;
  final VoidCallback? onTransferOwnership;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasActions =
        onPromoteAdmin != null || onDemoteMember != null || onTransferOwnership != null || onRemove != null;
    final (roleIcon, roleColor) = switch (member.role) {
      'owner' => (Icons.workspace_premium_rounded, scheme.primary),
      'admin' => (Icons.shield_outlined, scheme.tertiary),
      _ => (null, scheme.onSurfaceVariant),
    };
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      leading: InitialAvatar(name: member.displayName),
      title: Text(
        isSelf ? '${member.displayName} (du)' : member.displayName,
        style: TextStyle(fontWeight: isSelf ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          if (roleIcon != null) ...[
            Icon(roleIcon, size: 14, color: roleColor),
            const SizedBox(width: 4),
          ],
          Text(roleLabel, style: TextStyle(color: roleColor)),
        ],
      ),
      trailing: hasActions
          ? PopupMenuButton<_MemberAction>(
              enabled: !busy,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) => switch (action) {
                _MemberAction.promote => onPromoteAdmin?.call(),
                _MemberAction.demote => onDemoteMember?.call(),
                _MemberAction.transfer => onTransferOwnership?.call(),
                _MemberAction.remove => onRemove?.call(),
              },
              itemBuilder: (context) => [
                if (onPromoteAdmin != null)
                  _item(_MemberAction.promote, Icons.shield_outlined, l10n.groupPromoteAdmin),
                if (onDemoteMember != null)
                  _item(_MemberAction.demote, Icons.remove_moderator_outlined, l10n.groupDemoteMember),
                if (onTransferOwnership != null)
                  _item(_MemberAction.transfer, Icons.workspace_premium_outlined, l10n.groupTransferOwnership),
                if (onRemove != null) ...[
                  const PopupMenuDivider(),
                  _item(
                    _MemberAction.remove,
                    Icons.person_remove_outlined,
                    l10n.groupRemoveMember,
                    color: scheme.error,
                  ),
                ],
              ],
            )
          : null,
    );
  }

  PopupMenuItem<_MemberAction> _item(_MemberAction value, IconData icon, String label, {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

