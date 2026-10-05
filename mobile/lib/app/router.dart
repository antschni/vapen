import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/session_notifier.dart';
import '../data/permissions/required_permissions.dart';
import '../features/ble_explorer/ble_explorer_screen.dart';
import '../features/groups/group_detail_screen.dart';
import '../features/groups/group_members_screen.dart';
import '../features/groups/groups_screen.dart';
import '../features/groups/join_group_screen.dart';
import '../features/settings/account_screen.dart';
import '../features/settings/devices_screen.dart';
import '../features/settings/device_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/login_screen.dart';
import '../features/onboarding/register_screen.dart';
import '../features/onboarding/app_loading_screen.dart';
import '../features/onboarding/server_setup_screen.dart';
import '../features/pairing/pairing_screen.dart';
import '../features/permissions/permissions_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/settings/server_endpoint_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../l10n/app_localizations.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Notifies [GoRouter] when auth/session changes without recreating the router
/// (recreating would reset navigation to [GoRouter.initialLocation]).
final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);
  return GoRouter(
    navigatorKey: _rootKey,
    refreshListenable: refresh,
    initialLocation: '/loading',
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final permissions = ref.read(requiredPermissionsProvider);
      final loc = state.matchedLocation;
      const authRoutes = {'/login', '/register'};
      final onSetup = loc == '/setup';
      final onLoading = loc == '/loading';
      final onPermissions = loc == '/permissions';
      final onPairing = loc == '/pairing';
      final onServerSettings = loc == '/server';
      final onJoin = loc.startsWith('/groups/join');

      if (session.loading || permissions.loading) {
        return onLoading ? null : '/loading';
      }

      if (onLoading) {
        if (!session.serverSetupComplete) return '/setup';
        if (!session.isAuthenticated) return '/login';
        if (!permissions.granted) return '/permissions';
        return '/home';
      }

      if (!session.serverSetupComplete) {
        if (!onSetup && !onJoin) return '/setup';
        return null;
      }

      if (!session.isAuthenticated) {
        if (onSetup) return '/login';
        if (authRoutes.contains(loc) || onJoin) return null;
        if (onServerSettings) return '/login';
        return '/login';
      }

      if (session.isAuthenticated && !permissions.granted) {
        if (onPermissions || onPairing) return null;
        return '/permissions';
      }

      if (session.isAuthenticated && authRoutes.contains(loc)) return '/home';
      if (session.isAuthenticated && onSetup) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/loading', builder: (_, s) => const AppLoadingScreen()),
      GoRoute(path: '/setup', builder: (_, s) => const ServerSetupScreen()),
      GoRoute(path: '/login', builder: (_, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, s) => const RegisterScreen()),
      GoRoute(path: '/server', builder: (_, s) => const ServerEndpointScreen()),
      GoRoute(path: '/permissions', builder: (_, s) => const PermissionsScreen()),
      GoRoute(path: '/pairing', builder: (_, s) => const PairingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final l10n = AppLocalizations.of(context)!;
          final theme = Theme.of(context);
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              indicatorColor: theme.colorScheme.primaryContainer,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: l10n.homeTitle,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bar_chart_outlined),
                  selectedIcon: const Icon(Icons.bar_chart_rounded),
                  label: l10n.statsTitle,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups_outlined),
                  selectedIcon: const Icon(Icons.groups_rounded),
                  label: l10n.groupsTitle,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: l10n.settingsTitle,
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
                  GoRoute(
                    path: 'privacy',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => const PrivacyScreen(),
                  ),
                  GoRoute(
                    path: 'explorer',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => const BleExplorerScreen(),
                  ),
                  GoRoute(
                    path: 'account',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => const AccountScreen(),
                  ),
                  GoRoute(
                    path: 'devices',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) => const DevicesScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: _rootKey,
                        builder: (_, s) => DeviceDetailScreen(deviceId: s.pathParameters['id']!),
                      ),
                    ],
                  ),
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
        routes: [
          GoRoute(
            path: 'members',
            builder: (context, state) => GroupMembersScreen(groupId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/join/:code',
        redirect: (_, state) => '/groups/join?code=${state.pathParameters['code']}',
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(sessionProvider, (_, _) => notifyListeners());
    _ref.listen(requiredPermissionsProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}
