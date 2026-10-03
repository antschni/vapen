import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_providers.dart';
import '../../data/api/sse_client.dart';
import '../../data/auth/session_notifier.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  List<Map<String, dynamic>> _liveMembers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub == null) _connectLive();
  }

  void _connectLive() {
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gruppe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          FutureBuilder(
            future: ref.read(apiClientProvider).getGroupOverview(widget.groupId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final overview = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Leaderboard', style: Theme.of(context).textTheme.titleMedium),
                  ...overview.leaderboard.map(
                    (e) => ListTile(
                      title: Text('${e['display_name']}'),
                      trailing: Text('#${e['rank']}'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
