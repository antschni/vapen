import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/ui/widgets.dart';
import '../../data/auth/session_notifier.dart';
import '../../l10n/app_localizations.dart';

class ServerEndpointScreen extends ConsumerStatefulWidget {
  const ServerEndpointScreen({super.key});

  @override
  ConsumerState<ServerEndpointScreen> createState() => _ServerEndpointScreenState();
}

class _ServerEndpointScreenState extends ConsumerState<ServerEndpointScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(sessionProvider).baseUrl ?? defaultBaseUrl();
      _controller.text = current;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final url = normalizeBaseUrl(_controller.text);
    if (!isAllowedBaseUrl(url, isRelease: kReleaseMode)) {
      setState(() => _error = l10n.invalidServerUrl);
      return;
    }

    final session = ref.read(sessionProvider);
    final previous = normalizeBaseUrl(session.baseUrl ?? defaultBaseUrl());
    if (url != previous && session.isAuthenticated) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.serverEndpointTitle),
          content: Text(l10n.serverEndpointChangeLogout),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancelButton)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.serverEndpointSave)),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(sessionProvider.notifier).updateServerEndpoint(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.serverEndpointSaved)));
      context.pop();
    } on ArgumentError {
      setState(() => _error = l10n.invalidServerUrl);
    } on DioException {
      setState(() => _error = l10n.serverConnectionFailed);
    } catch (_) {
      setState(() => _error = l10n.genericError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverEndpointTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            l10n.serverEndpointDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
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
            enabled: !_saving,
            onSubmitted: (_) => _saving ? null : _save(),
          ),
          const SizedBox(height: 16),
          InfoBanner(
            icon: Icons.warning_amber_rounded,
            tone: BannerTone.neutral,
            text: l10n.serverEndpointChangeLogout,
          ),
          const SizedBox(height: 24),
          LoadingButton(
            label: l10n.serverEndpointSave,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
