import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../views/navigation/app_shell.dart';
import '../../views/home/home_view.dart';
import '../../views/search/search_view.dart';
import '../../views/library/library_view.dart';
import '../../views/settings/settings_view.dart';
import '../../views/auth/auth_view.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> homeNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> searchNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> libraryNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> settingsNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter({bool isAuthenticated = true, String initialLocation = '/home'}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthView(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeView(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: searchNavigatorKey,
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchView(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: libraryNavigatorKey,
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryView(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: settingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsView(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
