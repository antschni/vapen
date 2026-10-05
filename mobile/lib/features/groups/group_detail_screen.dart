import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/duration_format.dart';
import '../../core/relative_time_format.dart';
import '../../core/ui/widgets.dart';
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
  Timer? _ticker;
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
    // Live status decays with the clock (vaping → active → idle), so re-render periodically.
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _liveMembers.isNotEmpty) setState(() {});
    });
  }

  Future<(DateTime from, DateTime to, String tz)> _overviewQuery() async {
    final tz = (await FlutterTimezone.getLocalTimezone()).identifier;
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
    setState(() => _groupLoading = _group == null);
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

  Future<void> _refresh() async {
    await Future.wait([_loadGroup(), _loadOverview()]);
  }

  void _connectLive() {
    if (_sub != null) return;
    final session = ref.read(sessionProvider);
    final baseUrl = session.baseUrl;
    final token = session.accessToken;
    if (baseUrl == null || token == null) return;
    final client = GroupLiveSseClient(baseUrl: baseUrl, accessToken: token, groupId: widget.groupId);
    _sub = client.connect().listen(
      (event) {
        if (!mounted) return;
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
      },
      onError: (_) {},
    );
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
    _ticker?.cancel();
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
    final group = _group;
    final title = group?.name ?? l10n.groupsTitle;
    final myRole = _myRoleInGroup();
    final canManageMembers = myRole == 'owner' || myRole == 'admin';
    final myId = ref.watch(sessionProvider.select((s) => s.user?.id));
    final inviteCode = group?.inviteCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: canManageMembers ? l10n.groupMembersManage : l10n.groupMembersTitle,
            onPressed: _groupLoading ? null : _openMembers,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (_groupLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (group != null)
              _MembersHeader(
                group: group,
                manageLabel: canManageMembers ? l10n.groupMembersManage : l10n.groupMembersTitle,
                onTap: _openMembers,
              ),
            SectionHeader(
              'Live',
              trailing: _liveMembers.isEmpty ? null : _LiveCounter(members: _liveMembers),
            ),
            _LiveCard(members: _liveMembers, myId: myId),
            _LeaderboardSection(
              l10n: l10n,
              loading: _overviewLoading,
              entries: _overview?.leaderboard ?? [],
              range: _leaderboardRange,
              myId: myId,
              onRangeChanged: _setLeaderboardRange,
            ),
            if (!_groupLoading && inviteCode != null) ...[
              SectionHeader(l10n.groupInviteCode),
              _InviteCard(
                l10n: l10n,
                inviteCode: inviteCode,
                inviteUrl: _inviteUrl(inviteCode),
                onCopyCode: () => _copyToClipboard(inviteCode, l10n),
                onCopyLink: () {
                  final url = _inviteUrl(inviteCode);
                  if (url != null) _copyToClipboard(url, l10n);
                },
                onShare: () {
                  final url = _inviteUrl(inviteCode);
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'Tritt meiner Vapen-Gruppe „$title“ bei: ${url ?? inviteCode}',
                      subject: 'Einladung zu $title',
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MembersHeader extends StatelessWidget {
  const _MembersHeader({required this.group, required this.manageLabel, required this.onTap});

  final Group group;
  final String manageLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = group.members.take(5).toList();
    const radius = 18.0;
    const overlap = 12.0;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: shown.isEmpty ? 0 : radius * 2 + (shown.length - 1) * (radius * 2 - overlap),
                height: radius * 2,
                child: Stack(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      Positioned(
                        left: i * (radius * 2 - overlap),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.surfaceContainerLow, width: 2),
                          ),
                          child: InitialAvatar(name: shown[i].displayName, radius: radius - 2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.memberCount == 1 ? '1 Mitglied' : '${group.memberCount} Mitglieder',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      manageLabel,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveEntry {
  _LiveEntry(Map<String, dynamic> m)
      : userId = m['user_id'] as String?,
        name = m['display_name'] as String? ?? '—',
        lastPuff = m['last_puff_at'] != null ? DateTime.parse(m['last_puff_at'] as String) : null,
        status = deriveLiveStatus(
          vapingSince: m['vaping_since'] != null ? DateTime.parse(m['vaping_since'] as String) : null,
          lastPuffAt: m['last_puff_at'] != null ? DateTime.parse(m['last_puff_at'] as String) : null,
        );

  final String? userId;
  final String name;
  final DateTime? lastPuff;
  final LiveMemberStatus status;
}

class _LiveCounter extends StatelessWidget {
  const _LiveCounter({required this.members});

  final List<Map<String, dynamic>> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vaping = members.map(_LiveEntry.new).where((e) => e.status == LiveMemberStatus.vaping).length;
    if (vaping == 0) return const SizedBox.shrink();
    return Text(
      '$vaping dampft gerade',
      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.members, required this.myId});

  final List<Map<String, dynamic>> members;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (members.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.wifi_tethering_off_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Noch keine Live-Daten — Mitglieder müssen den Live-Status teilen.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final entries = members.map(_LiveEntry.new).toList()
      ..sort((a, b) {
        final byStatus = a.status.index.compareTo(b.status.index);
        if (byStatus != 0) return byStatus;
        return (b.lastPuff ?? DateTime(0)).compareTo(a.lastPuff ?? DateTime(0));
      });
    return GroupedCard(
      children: [
        for (final e in entries)
          ListTile(
            leading: InitialAvatar(name: e.name),
            title: Text(e.userId != null && e.userId == myId ? '${e.name} (du)' : e.name),
            subtitle: Text(
              e.lastPuff != null ? 'Letzter Zug ${formatRelativeTimeDe(e.lastPuff!)}' : 'Noch kein Zug',
            ),
            trailing: _StatusPill(status: e.status),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final LiveMemberStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (label, bg, fg) = switch (status) {
      LiveMemberStatus.vaping => ('Dampft', scheme.primary, scheme.onPrimary),
      LiveMemberStatus.active => ('Aktiv', scheme.tertiaryContainer, scheme.onTertiaryContainer),
      LiveMemberStatus.idle => ('Inaktiv', scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
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
    required this.myId,
    required this.onRangeChanged,
  });

  final AppLocalizations l10n;
  final bool loading;
  final List<Map<String, dynamic>> entries;
  final _LeaderboardRange range;
  final String? myId;
  final ValueChanged<_LeaderboardRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.groupLeaderboard),
        SegmentedButton<_LeaderboardRange>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: _LeaderboardRange.today, label: Text(l10n.groupRangeToday)),
            ButtonSegment(value: _LeaderboardRange.week, label: Text(l10n.groupRange7d)),
            ButtonSegment(value: _LeaderboardRange.month, label: Text(l10n.groupRange30d)),
          ],
          selected: {range},
          onSelectionChanged: (s) => onRangeChanged(s.first),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: loading
              ? const Padding(
                  key: ValueKey('loading'),
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : entries.isEmpty
                  ? Card(
                      key: const ValueKey('empty'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.emoji_events_outlined, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Keine Einträge — Privatsphäre oder keine Züge im Zeitraum.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GroupedCard(
                      key: ValueKey(range),
                      children: [
                        for (var i = 0; i < entries.length; i++) _rankTile(context, entries[i], i),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _rankTile(BuildContext context, Map<String, dynamic> e, int i) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rank = e['rank'] as int? ?? i + 1;
    final name = e['display_name'] as String? ?? '—';
    final puffs = e['puff_count'] as int? ?? 0;
    final durationMs = e['total_duration_ms'] as int? ?? 0;
    final isMe = myId != null && e['user_id'] == myId;
    final medal = switch (rank) {
      1 => const Color(0xFFE0A526),
      2 => const Color(0xFF9EA7B0),
      3 => const Color(0xFFB87333),
      _ => null,
    };
    return Container(
      color: isMe ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: ListTile(
        leading: SizedBox(
          width: 40,
          child: Center(
            child: medal != null
                ? Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: medal.withValues(alpha: 0.18), shape: BoxShape.circle),
                    child: Icon(Icons.emoji_events_rounded, color: medal, size: 20),
                  )
                : Text(
                    '#$rank',
                    style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
          ),
        ),
        title: Text(isMe ? '$name (du)' : name, style: TextStyle(fontWeight: isMe ? FontWeight.w700 : null)),
        subtitle: Text(formatDurationMs(durationMs)),
        trailing: Text(
          l10n.groupLeaderboardPuffs(_leaderboardCountFormat.format(puffs)),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
    required this.onShare,
  });

  final AppLocalizations l10n;
  final String inviteCode;
  final String? inviteUrl;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyLink;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (inviteUrl != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: inviteUrl!,
                  size: 168,
                  padding: EdgeInsets.zero,
                  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.circle, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            InkWell(
              onTap: onCopyCode,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      inviteCode,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy_rounded, size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'QR-Code scannen lassen oder Code teilen',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (inviteUrl != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCopyLink,
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: Text(l10n.groupCopyLink),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Teilen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
