import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/ui/widgets.dart';
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
  bool _showPassword = false;

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

    return AutofillGroup(
      child: AuthScaffold(
        title: l10n.registerTitle,
        subtitle: 'Erstelle ein Konto, um deine Züge zu tracken und mit Freunden zu teilen.',
        children: [
          if (baseUrl != null) ...[
            ServerChip(url: baseUrl),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _displayName,
            decoration: InputDecoration(
              labelText: l10n.displayNameLabel,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.nickname],
            enabled: !_submitting,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: InputDecoration(
              labelText: l10n.emailLabel,
              prefixIcon: const Icon(Icons.alternate_email_rounded),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            enabled: !_submitting,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Verbergen' : 'Anzeigen',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              ),
            ),
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            enabled: !_submitting,
            onSubmitted: (_) => _submitting ? null : _submit(),
          ),
          if (_error != null) FormError(_error!),
          const SizedBox(height: 24),
          LoadingButton(
            label: l10n.registerButton,
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
