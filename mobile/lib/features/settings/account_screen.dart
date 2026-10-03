import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

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

  Future<void> _saveProfile() async {
    final tz = await FlutterTimezone.getLocalTimezone();
    final user = await ref.read(apiClientProvider).patchMe(
          displayName: _displayName.text.trim(),
          timezone: tz,
        );
    ref.read(sessionProvider.notifier).setUser(user);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil gespeichert')));
    }
  }

  Future<void> _changePassword() async {
    await ref.read(apiClientProvider).changePassword(
          currentPassword: _currentPw.text,
          newPassword: _newPw.text,
        );
    _currentPw.clear();
    _newPw.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwort geändert')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _displayName, decoration: const InputDecoration(labelText: 'Anzeigename')),
          FilledButton(onPressed: _saveProfile, child: const Text('Speichern')),
          const Divider(),
          TextField(controller: _currentPw, decoration: const InputDecoration(labelText: 'Aktuelles Passwort'), obscureText: true),
          TextField(controller: _newPw, decoration: const InputDecoration(labelText: 'Neues Passwort'), obscureText: true),
          FilledButton(onPressed: _changePassword, child: const Text('Passwort ändern')),
        ],
      ),
    );
  }
}
