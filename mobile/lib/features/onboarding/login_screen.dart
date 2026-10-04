import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/config.dart';
import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadServerUrl());
  }

  Future<void> _loadServerUrl() async {
    final storage = ref.read(tokenStorageProvider);
    final preferred = await storage.readPreferredServerUrl();
    final fromSession = ref.read(sessionProvider).baseUrl;
    if (!mounted) return;
    _server.text = fromSession ?? preferred ?? defaultBaseUrl();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final baseUrl = normalizeBaseUrl(_server.text);
    if (!isAllowedBaseUrl(baseUrl, isRelease: kReleaseMode)) {
      setState(() => _error = l10n.invalidServerUrl);
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(sessionProvider.notifier).login(
            baseUrl: baseUrl,
            email: _email.text.trim(),
            password: _password.text,
          );
      if (mounted) context.go('/permissions');
    } on VapenApiException catch (e) {
      setState(() => _error = e.problem.code == 'invalid_credentials' ? l10n.invalidCredentials : l10n.genericError);
    } catch (_) {
      setState(() => _error = l10n.genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _server,
            decoration: InputDecoration(labelText: l10n.serverUrlLabel),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: InputDecoration(labelText: l10n.emailLabel),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: InputDecoration(labelText: l10n.passwordLabel),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _submit, child: Text(l10n.loginButton)),
          TextButton(onPressed: () => context.push('/register'), child: Text(l10n.registerTitle)),
          TextButton(onPressed: () => context.push('/server'), child: Text(l10n.serverEndpointTitle)),
        ],
      ),
    );
  }
}
