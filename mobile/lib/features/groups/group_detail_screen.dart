import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/duration_format.dart';
import '../../data/api/api_providers.dart';
import '../../data/api/sse_client.dart';
import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';

enum _LeaderboardRange { today, week, month }

final _leaderboardCountFormat = NumberFormat.decimalPattern('de_DE');

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  List<Map<String, dynamic>> _liveMembers = [];
  Group? _group;
  bool _groupLoading = true;
  GroupOverview? _overview;
  bool _overviewLoading = true;
  _LeaderboardRange _leaderboardRange = _LeaderboardRange.week;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroup();
      _loadOverview();
      _connectLive();
    });
  }

  Future<(DateTime from, DateTime to, String tz)> _overviewQuery() async {
    final tz = await FlutterTimezone.getLocalTimezone();
    final now = DateTime.now();
    final to = now.toUtc();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final from = switch (_leaderboardRange) {
      _LeaderboardRange.today => startOfToday,
      _LeaderboardRange.week => startOfToday.subtract(const Duration(days: 6)),
      _LeaderboardRange.month => startOfToday.subtract(const Duration(days: 29)),
    };
    return (from.toUtc(), to, tz);
  }

  Future<void> _loadOverview() async {
    setState(() => _overviewLoading = true);
    try {
      final (from, to, tz) = await _overviewQuery();
      final overview = await ref.read(apiClientProvider).getGroupOverview(
            widget.groupId,
            from: from,
            to: to,
            tz: tz,
          );
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _overviewLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _overviewLoading = false);
    }
  }

  void _setLeaderboardRange(_LeaderboardRange range) {
    if (_leaderboardRange == range) return;
    setState(() => _leaderboardRange = range);
    _loadOverview();
  }

  Future<void> _loadGroup() async {
    setState(() => _groupLoading = true);
    try {
      final group = await ref.read(apiClientProvider).getGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        _group = group;
        _groupLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _groupLoading = false);
    }
  }

  void _connectLive() {
    if (_sub != null) return;
    final session = ref.read(sessionProvider);
    final baseUrl = session.baseUrl;
    final token = session.accessToken;
    if (baseUrl == null || token == null) return;
    final client = GroupLiveSseClient(baseUrl: baseUrl, accessToken: token, groupId: widget.groupId);
    _sub = client.connect().listen((event) {
      if (event['event'] == 'snapshot') {
        final data = event['data'] as Map<String, dynamic>;
        setState(() => _liveMembers = (data['members'] as List).cast<Map<String, dynamic>>());
      } else if (event['event'] == 'member_update') {
        final update = event['data'] as Map<String, dynamic>;
        setState(() {
          final idx = _liveMembers.indexWhere((m) => m['user_id'] == update['user_id']);
          if (idx >= 0) {
            _liveMembers[idx] = update;
          } else {
            _liveMembers.add(update);
          }
        });
      }
    });
  }

  Future<void> _copyToClipboard(String text, AppLocalizations l10n) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.groupInviteCopied)));
  }

  String? _inviteUrl(String code) {
    final baseUrl = ref.read(sessionProvider).baseUrl;
    if (baseUrl == null) return null;
    final origin = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$origin/join/$code';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _openMembers() async {
    await context.push('/groups/${widget.groupId}/members');
    if (mounted) _loadGroup();
  }

  String? _myRoleInGroup() {
    final uid = ref.read(sessionProvider).user?.id;
    final group = _group;
    if (uid == null || group == null) return null;
    for (final m in group.members) {
      if (m.userId == uid) return m.role;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _group?.name ?? l10n.groupsTitle;
    final myRole = _myRoleInGroup();
    final canManageMembers = myRole == 'owner' || myRole == 'admin';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: canManageMembers ? l10n.groupMembersManage : l10n.groupMembersTitle,
            onPressed: _groupLoading ? null : _openMembers,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_groupLoading)
            const LinearProgressIndicator()
          else if (_group != null) ...[
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(l10n.groupMembersTitle),
                subtitle: Text('${_group!.memberCount} ${l10n.groupMembersTitle.toLowerCase()}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openMembers,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_groupLoading && _group?.inviteCode != null) ...[
            _InviteCard(
              l10n: l10n,
              inviteCode: _group!.inviteCode!,
              inviteUrl: _inviteUrl(_group!.inviteCode!),
              onCopyCode: () => _copyToClipboard(_group!.inviteCode!, l10n),
              onCopyLink: () {
                final url = _inviteUrl(_group!.inviteCode!);
                if (url != null) _copyToClipboard(url, l10n);
              },
            ),
            const SizedBox(height: 16),
          ],
          Text('Live', style: Theme.of(context).textTheme.titleMedium),
          ..._liveMembers.map((m) {
            final vapingSince = m['vaping_since'] != null ? DateTime.parse(m['vaping_since'] as String) : null;
            final lastPuff = m['last_puff_at'] != null ? DateTime.parse(m['last_puff_at'] as String) : null;
            final status = deriveLiveStatus(vapingSince: vapingSince, lastPuffAt: lastPuff);
            return ListTile(
              title: Text(m['display_name'] as String? ?? '—'),
              trailing: Text(status.name),
            );
          }),
          const Divider(),
          _LeaderboardSection(
            l10n: l10n,
            loading: _overviewLoading,
            entries: _overview?.leaderboard ?? [],
            range: _leaderboardRange,
            onRangeChanged: _setLeaderboardRange,
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({
    required this.l10n,
    required this.loading,
    required this.entries,
    required this.range,
    required this.onRangeChanged,
  });

  final AppLocalizations l10n;
  final bool loading;
  final List<Map<String, dynamic>> entries;
  final _LeaderboardRange range;
  final ValueChanged<_LeaderboardRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.groupLeaderboard, style: theme.textTheme.titleMedium),
            ),
            _RangeChip(
              label: l10n.groupRangeToday,
              selected: range == _LeaderboardRange.today,
              onTap: () => onRangeChanged(_LeaderboardRange.today),
            ),
            const SizedBox(width: 4),
            _RangeChip(
              label: l10n.groupRange7d,
              selected: range == _LeaderboardRange.week,
              onTap: () => onRangeChanged(_LeaderboardRange.week),
            ),
            const SizedBox(width: 4),
            _RangeChip(
              label: l10n.groupRange30d,
              selected: range == _LeaderboardRange.month,
              onTap: () => onRangeChanged(_LeaderboardRange.month),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading)
          const LinearProgressIndicator()
        else if (entries.isEmpty)
          Text(
            'Keine Einträge — Privatsphäre oder keine Züge im Zeitraum.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          Card(
            elevation: 0,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
              itemBuilder: (context, i) {
                final e = entries[i];
                final rank = e['rank'] as int? ?? i + 1;
                final name = e['display_name'] as String? ?? '—';
                final puffs = e['puff_count'] as int? ?? 0;
                final durationMs = e['total_duration_ms'] as int? ?? 0;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _rankColor(theme.colorScheme, rank).withValues(alpha: 0.2),
                    child: Text(
                      '#$rank',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _rankColor(theme.colorScheme, rank),
                      ),
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text(
                    '${l10n.groupLeaderboardPuffs(_leaderboardCountFormat.format(puffs))} · ${formatDurationMs(durationMs)}',
                  ),
                  trailing: Icon(Icons.emoji_events_outlined, color: _rankColor(theme.colorScheme, rank)),
                );
              },
            ),
          ),
      ],
    );
  }

  Color _rankColor(ColorScheme scheme, int rank) {
    return switch (rank) {
      1 => scheme.primary,
      2 => scheme.secondary,
      3 => scheme.tertiary,
      _ => scheme.onSurfaceVariant,
    };
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.l10n,
    required this.inviteCode,
    required this.inviteUrl,
    required this.onCopyCode,
    required this.onCopyLink,
  });

  final AppLocalizations l10n;
  final String inviteCode;
  final String? inviteUrl;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.groupInviteCode, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              inviteCode,
              style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'monospace', letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onCopyCode,
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.groupCopyCode),
                ),
                if (inviteUrl != null)
                  OutlinedButton.icon(
                    onPressed: onCopyLink,
                    icon: const Icon(Icons.link, size: 18),
                    label: Text(l10n.groupCopyLink),
                  ),
              ],
            ),
            if (inviteUrl != null) ...[
              const SizedBox(height: 12),
              Text(l10n.groupInviteLink, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(
                inviteUrl!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
