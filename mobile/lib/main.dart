import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/join_link.dart';
import 'data/auth/session_notifier.dart';
import 'data/native/tracking_bridge.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final tracking = TrackingBridge();
  runApp(
    ProviderScope(
      overrides: [
        trackingBridgeProvider.overrideWithValue(tracking),
      ],
      child: const VapenApp(),
    ),
  );
}

class VapenApp extends ConsumerStatefulWidget {
  const VapenApp({super.key});

  @override
  ConsumerState<VapenApp> createState() => _VapenAppState();
}

class _VapenAppState extends ConsumerState<VapenApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _appLinks.uriLinkStream.listen(_onJoinInviteUri);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _onJoinInviteUri(uri);
    });
  }

  Future<void> _onJoinInviteUri(Uri uri) async {
    final invite = JoinInviteLink.tryParse(uri);
    if (invite == null || !invite.isAllowedOrigin(isRelease: kReleaseMode)) return;

    try {
      await ref.read(sessionProvider.notifier).updateServerEndpoint(invite.origin);
    } catch (_) {
      // Server unreachable; still show join screen with the code.
    }
    if (!mounted) return;
    ref.read(routerProvider).go('/groups/join?code=${invite.code}');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: VapenTheme.light(),
      darkTheme: VapenTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
