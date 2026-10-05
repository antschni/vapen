import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/widgets.dart';
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
  bool _joining = false;

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
    setState(() {
      _error = null;
      _joining = true;
    });
    try {
      final group = await ref.read(apiClientProvider).joinGroup(code);
      if (mounted) context.go('/groups/${group.id}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Beitritt fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Gruppe beitreten',
      subtitle: 'Gib den 10-stelligen Einladungscode ein, den du bekommen hast.',
      showLogo: false,
      children: [
        TextField(
          controller: _code,
          autofocus: widget.initialCode == null,
          maxLength: 10,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 4,
              ),
          decoration: const InputDecoration(
            hintText: 'XXXXXXXXXX',
            counterText: '',
          ),
          enabled: !_joining,
          onSubmitted: (_) => _join(),
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 24),
        LoadingButton(
          label: 'Beitreten',
          icon: Icons.group_add_outlined,
          loading: _joining,
          onPressed: _join,
        ),
      ],
    );
  }
}
