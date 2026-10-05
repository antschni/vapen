import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/ui/widgets.dart';
import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';

class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialUrl());
  }

  Future<void> _loadInitialUrl() async {
    final storage = ref.read(tokenStorageProvider);
    final preferred = await storage.readPreferredServerUrl();
    final fromSession = ref.read(sessionProvider).baseUrl;
    if (!mounted) return;
    _controller.text = fromSession ?? preferred ?? defaultBaseUrl();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context)!;
    final url = normalizeBaseUrl(_controller.text);
    if (!isAllowedBaseUrl(url, isRelease: kReleaseMode)) {
      setState(() => _error = l10n.invalidServerUrl);
      return;
    }

    setState(() {
      _error = null;
      _testing = true;
    });
    try {
      await ref.read(sessionProvider.notifier).testAndSaveServer(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.serverConnectionSuccess)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      context.go('/login');
    } on ArgumentError {
      setState(() => _error = l10n.invalidServerUrl);
    } on DioException {
      setState(() => _error = l10n.serverConnectionFailed);
    } catch (_) {
      setState(() => _error = l10n.serverConnectionFailed);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider);
    final canGoBackToLogin = session.serverSetupComplete;

    return AuthScaffold(
      title: l10n.serverSetupTitle,
      subtitle: l10n.serverSetupDescription,
      leading: canGoBackToLogin ? BackButton(onPressed: () => context.go('/login')) : null,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: l10n.serverUrlLabel,
            hintText: 'https://vapen.example.com',
            prefixIcon: const Icon(Icons.dns_outlined),
            errorText: _error,
            errorMaxLines: 3,
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
          enabled: !_testing,
          onSubmitted: (_) => _testing ? null : _testConnection(),
        ),
        const SizedBox(height: 24),
        LoadingButton(
          label: l10n.serverConnectionTestButton,
          loading: _testing,
          onPressed: _testConnection,
        ),
      ],
    );
  }
}
