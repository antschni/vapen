import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/session_notifier.dart';
import '../features/ble_explorer/ble_explorer_screen.dart';
import '../features/groups/group_detail_screen.dart';
import '../features/groups/groups_screen.dart';
import '../features/groups/join_group_screen.dart';
import '../features/settings/account_screen.dart';
import '../features/settings/devices_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/login_screen.dart';
import '../features/onboarding/register_screen.dart';
import '../features/pairing/pairing_screen.dart';
import '../features/permissions/permissions_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/settings/server_endpoint_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/login',
    redirect: (context, state) {
      if (session.loading) return null;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final configuringServer = state.matchedLocation == '/server';
      if (!session.isAuthenticated && !loggingIn && !configuringServer) return '/login';
      if (session.isAuthenticated && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, s) => const RegisterScreen()),
      GoRoute(path: '/server', builder: (_, s) => const ServerEndpointScreen()),
      GoRoute(path: '/permissions', builder: (_, s) => const PermissionsScreen()),
      GoRoute(path: '/pairing', builder: (_, s) => const PairingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Statistik',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: 'Gruppen',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Mehr',
                ),
              ],
            ),
          );
        },
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, s) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/stats', builder: (_, s) => const StatsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/groups', builder: (_, s) => const GroupsScreen())]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, s) => const SettingsScreen(),
                routes: [
                  GoRoute(path: 'privacy', builder: (_, s) => const PrivacyScreen()),
                  GoRoute(path: 'explorer', builder: (_, s) => const BleExplorerScreen()),
                  GoRoute(path: 'account', builder: (_, s) => const AccountScreen()),
                  GoRoute(path: 'devices', builder: (_, s) => const DevicesScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/groups/join',
        builder: (context, state) => JoinGroupScreen(initialCode: state.uri.queryParameters['code']),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) => GroupDetailScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/join/:code',
        redirect: (_, state) => '/groups/join?code=${state.pathParameters['code']}',
      ),
    ],
  );
});
