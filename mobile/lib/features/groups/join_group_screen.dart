import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_providers.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  late final TextEditingController _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
    if (widget.initialCode != null && widget.initialCode!.length == 10) {
      Future.microtask(_join);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length != 10) {
      setState(() => _error = 'Code muss 10 Zeichen haben');
      return;
    }
    setState(() => _error = null);
    try {
      final group = await ref.read(apiClientProvider).joinGroup(code);
      if (mounted) context.go('/groups/${group.id}');
    } catch (_) {
      setState(() => _error = 'Beitritt fehlgeschlagen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gruppe beitreten')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Einladungscode'),
              maxLength: 10,
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            FilledButton(onPressed: _join, child: const Text('Beitreten')),
          ],
        ),
      ),
    );
  }
}
