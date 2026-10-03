import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'app/theme.dart';
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

final trackingBridgeProvider = Provider<TrackingBridge>((ref) => TrackingBridge());

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
    _appLinks.uriLinkStream.listen((uri) {
      final code = uri.pathSegments.last;
      if (uri.path.contains('/join') && code.length == 10) {
        ref.read(routerProvider).go('/groups/join?code=$code');
      }
    });
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
