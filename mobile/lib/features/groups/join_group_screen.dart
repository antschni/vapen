import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/join_link.dart';
import '../../core/ui/widgets.dart';
import '../../data/api/api_providers.dart';
import '../../data/auth/session_notifier.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, this.initialCode, this.serverOrigin});

  final String? initialCode;

  /// Origin of the server that issued an invite link; may differ from the current server.
  final String? serverOrigin;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  late final TextEditingController _code;
  String? _error;
  bool _joining = false;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode;
    _code = TextEditingController(
      text: initial != null && JoinInviteLink.isValidCode(initial) ? initial : '',
    );
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Invite origin when it is a valid server other than the one we are connected to.
  String? _foreignServer(String? currentBaseUrl) {
    final origin = widget.serverOrigin;
    if (origin == null || !isAllowedBaseUrl(origin, isRelease: kReleaseMode)) return null;
    final normalized = normalizeBaseUrl(origin);
    if (currentBaseUrl != null && normalizeBaseUrl(currentBaseUrl) == normalized) return null;
    return normalized;
  }

  Future<void> _switchServer(String origin) async {
    final signedIn = ref.read(sessionProvider).isAuthenticated;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server wechseln?'),
        content: Text(
          'Diese Einladung stammt von $origin. Wechsle nur, wenn du diesem Server vertraust.'
          '${signedIn ? ' Du wirst dabei abgemeldet.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Wechseln')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _error = null;
      _switching = true;
    });
    try {
      await ref.read(sessionProvider.notifier).updateServerEndpoint(origin);
    } catch (_) {
      if (mounted) setState(() => _error = 'Server nicht erreichbar');
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _join() async {
    if (_joining) return;
    final code = _code.text.trim();
    if (!JoinInviteLink.isValidCode(code)) {
      setState(() => _error = 'Code muss 10 Zeichen haben');
      return;
    }
    setState(() {
      _error = null;
      _joining = true;
    });
    try {
      final group = await ref.read(apiClientProvider).joinGroup(code);
      if (mounted) context.go('/groups/${Uri.encodeComponent(group.id)}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Beitritt fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final foreignServer = _foreignServer(session.baseUrl);
    final busy = _joining || _switching;
    return AuthScaffold(
      title: 'Gruppe beitreten',
      subtitle: 'Gib den 10-stelligen Einladungscode ein, den du bekommen hast.',
      showLogo: false,
      children: [
        if (foreignServer != null) ...[
          InfoBanner(
            icon: Icons.warning_amber_rounded,
            tone: BannerTone.neutral,
            text: 'Diese Einladung gehört zu $foreignServer, du bist aber mit '
                '${session.baseUrl ?? '–'} verbunden.',
          ),
          const SizedBox(height: 16),
        ],
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
          enabled: !busy,
          onSubmitted: (_) {
            if (foreignServer == null && session.isAuthenticated) _join();
          },
        ),
        if (_error != null) FormError(_error!),
        const SizedBox(height: 24),
        if (foreignServer != null)
          LoadingButton(
            label: 'Server wechseln',
            icon: Icons.dns_outlined,
            loading: _switching,
            onPressed: () => _switchServer(foreignServer),
          )
        else if (!session.isAuthenticated)
          LoadingButton(
            label: 'Anmelden',
            icon: Icons.login,
            loading: false,
            onPressed: () => context.go('/login'),
          )
        else
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
