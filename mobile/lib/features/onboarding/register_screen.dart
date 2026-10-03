import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/config.dart';
import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  final _server = TextEditingController(text: defaultBaseUrl());
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final baseUrl = _server.text.trim();
    if (!isAllowedBaseUrl(baseUrl, isRelease: bool.fromEnvironment('dart.vm.product'))) {
      setState(() => _error = 'Ungültige Server-URL');
      return;
    }
    setState(() => _error = null);
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      await ref.read(sessionProvider.notifier).register(
            baseUrl: baseUrl,
            email: _email.text.trim(),
            password: _password.text,
            displayName: _displayName.text.trim(),
            timezone: tz,
          );
      if (mounted) context.go('/permissions');
    } on VapenApiException {
      setState(() => _error = l10n.genericError);
    } catch (_) {
      setState(() => _error = l10n.genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _server, decoration: InputDecoration(labelText: l10n.serverUrlLabel)),
          const SizedBox(height: 12),
          TextField(controller: _displayName, decoration: InputDecoration(labelText: l10n.displayNameLabel)),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: InputDecoration(labelText: l10n.emailLabel)),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: InputDecoration(labelText: l10n.passwordLabel),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _submit, child: Text(l10n.registerButton)),
        ],
      ),
    );
  }
}
