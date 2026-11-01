import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/join_link.dart';
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
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // uriLinkStream also emits the launch link; getInitialLink would handle it twice.
    _linkSub = _appLinks.uriLinkStream.listen(_onJoinInviteUri);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  /// Any website can open an invite link, so never switch servers or join here.
  /// The join screen asks the user before acting on a foreign server.
  void _onJoinInviteUri(Uri uri) {
    final invite = JoinInviteLink.tryParse(uri);
    if (invite == null || !invite.isAllowedOrigin(isRelease: kReleaseMode)) return;
    if (!mounted) return;
    final target = Uri(
      path: '/groups/join',
      queryParameters: {'code': invite.code, 'server': invite.origin},
    );
    ref.read(routerProvider).go(target.toString());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Vapen',
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
