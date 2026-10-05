import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/ui/widgets.dart';
import '../../data/auth/session_notifier.dart';
import '../../data/devices/account_devices.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(sessionProvider.notifier).login(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      context.go(await routeAfterAuth(ref));
    } on VapenApiException catch (e) {
      setState(() => _error = e.problem.code == 'invalid_credentials' ? l10n.invalidCredentials : l10n.genericError);
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
        title: 'Willkommen zurück',
        subtitle: 'Melde dich an, um dein Tracking fortzusetzen.',
        children: [
          if (baseUrl != null) ...[
            ServerChip(
              url: baseUrl,
              label: l10n.changeServerButton,
              onChange: _submitting ? null : () => context.go('/setup'),
            ),
            const SizedBox(height: 20),
          ],
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
            autofillHints: const [AutofillHints.password],
            enabled: !_submitting,
            onSubmitted: (_) => _submitting ? null : _submit(),
          ),
          if (_error != null) FormError(_error!),
          const SizedBox(height: 24),
          LoadingButton(
            label: l10n.loginButton,
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Noch kein Konto?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              TextButton(
                onPressed: _submitting ? null : () => context.push('/register'),
                child: Text(l10n.registerTitle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
