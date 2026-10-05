import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

import '../../data/auth/session_notifier.dart';
import '../../data/devices/account_devices.dart';
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
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      await ref.read(sessionProvider.notifier).register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _displayName.text.trim(),
            timezone: tz,
          );
      if (!mounted) return;
      context.go(await routeAfterAuth(ref));
    } on VapenApiException {
      setState(() => _error = l10n.genericError);
    } catch (_) {
      setState(() => _error = l10n.genericError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final baseUrl = ref.watch(sessionProvider).baseUrl;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (baseUrl != null) ...[
            Text(
              l10n.serverConfiguredHint(baseUrl),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _displayName,
            decoration: InputDecoration(labelText: l10n.displayNameLabel),
            enabled: !_submitting,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: InputDecoration(labelText: l10n.emailLabel),
            enabled: !_submitting,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: InputDecoration(labelText: l10n.passwordLabel),
            obscureText: true,
            enabled: !_submitting,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.registerButton),
          ),
        ],
      ),
    );
  }
}
