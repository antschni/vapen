import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:vapen_api/vapen_api.dart';

import '../../core/ui/widgets.dart';
import '../../data/api/api_providers.dart';
import '../../data/auth/session_notifier.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _displayName = TextEditingController();
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _showPasswords = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    _displayName.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _displayName.dispose();
    _currentPw.dispose();
    _newPw.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      final tz = (await FlutterTimezone.getLocalTimezone()).identifier;
      final user = await ref.read(apiClientProvider).patchMe(
            displayName: _displayName.text.trim(),
            timezone: tz,
          );
      ref.read(sessionProvider.notifier).setUser(user);
      _snack('Profil gespeichert');
    } on VapenApiException catch (e) {
      _snack(e.problem.detail ?? 'Speichern fehlgeschlagen');
    } catch (_) {
      _snack('Speichern fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentPw.text.isEmpty || _newPw.text.isEmpty) {
      _snack('Bitte beide Passwortfelder ausfüllen');
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await ref.read(apiClientProvider).changePassword(
            currentPassword: _currentPw.text,
            newPassword: _newPw.text,
          );
      _currentPw.clear();
      _newPw.clear();
      _snack('Passwort geändert');
    } on VapenApiException catch (e) {
      _snack(e.problem.detail ?? 'Passwort konnte nicht geändert werden');
    } catch (_) {
      _snack('Passwort konnte nicht geändert werden');
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(sessionProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Center(
            child: Column(
              children: [
                InitialAvatar(name: user?.displayName ?? user?.email ?? '?', radius: 40),
                const SizedBox(height: 12),
                Text(user?.email ?? '', style: theme.textTheme.titleMedium),
                if (user != null)
                  Text(
                    'Dabei seit ${DateFormat('MMMM yyyy', 'de').format(user.createdAt.toLocal())}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SectionHeader('Profil'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _displayName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Anzeigename',
                      prefixIcon: Icon(Icons.badge_outlined),
                      helperText: 'So sehen dich andere in Gruppen',
                    ),
                  ),
                  const SizedBox(height: 16),
                  LoadingButton(
                    label: 'Speichern',
                    loading: _savingProfile,
                    onPressed: _saveProfile,
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Passwort'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _currentPw,
                    obscureText: !_showPasswords,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Aktuelles Passwort',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _showPasswords ? 'Verbergen' : 'Anzeigen',
                        onPressed: () => setState(() => _showPasswords = !_showPasswords),
                        icon: Icon(_showPasswords ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPw,
                    obscureText: !_showPasswords,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Neues Passwort',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LoadingButton(
                    label: 'Passwort ändern',
                    loading: _savingPassword,
                    onPressed: _changePassword,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
