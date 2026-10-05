import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/vapen_logo.dart';
import '../../data/auth/session_notifier.dart';
import '../../data/permissions/required_permissions.dart';
import '../../l10n/app_localizations.dart';

/// Shown while persisted session and server URL are restored on cold start.
///
/// Also leaves this route itself once restore finishes. GoRouter's redirect can
/// lose a race when [session.loading] flips twice in quick succession (login
/// used to do that) and the last navigation lands here with loading already false.
class AppLoadingScreen extends ConsumerStatefulWidget {
  const AppLoadingScreen({super.key});

  @override
  ConsumerState<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends ConsumerState<AppLoadingScreen> {
  var _leaving = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final permissions = ref.watch(requiredPermissionsProvider);
    final ready = !session.loading && !permissions.loading;
    if (ready) {
      final target = !session.serverSetupComplete
          ? '/setup'
          : !session.isAuthenticated
              ? '/login'
              : !permissions.granted
                  ? '/permissions'
                  : '/home';
      if (!_leaving) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final loc = GoRouterState.of(context).matchedLocation;
          if (loc == '/loading') context.go(target);
        });
      }
    } else {
      _leaving = false;
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VapenLogo(size: 72),
            const SizedBox(height: 20),
            Text(
              l10n.appTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
