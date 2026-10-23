import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/services/state_persistence_service.dart';
import '../../controllers/audio_player_controller.dart';
import '../../core/navigation/app_router.dart';
import '../shared_widgets/spotify_logo.dart';
import 'mini_player.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const List<String> _branchRoutes = [
    '/home',
    '/search',
    '/library',
    '/settings',
  ];

  GlobalKey<NavigatorState>? _getNavigatorKeyForBranch(int index) {
    switch (index) {
      case 0:
        return homeNavigatorKey;
      case 1:
        return searchNavigatorKey;
      case 2:
        return libraryNavigatorKey;
      case 3:
        return settingsNavigatorKey;
      default:
        return null;
    }
  }

  void _onTabTapped(BuildContext context, WidgetRef ref, int index) {
    // If user tapped the tab that is already selected
    if (index == navigationShell.currentIndex) {
      final navKey = _getNavigatorKeyForBranch(index);
      if (navKey?.currentState?.canPop() ?? false) {
        // Pop all stacked routes on this tab until we reach the root
        navKey!.currentState!.popUntil((route) => route.isFirst);
        return;
      }
    }

    // Otherwise navigate to or switch to branch (initialLocation: true if already on same tab)
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );

    // Persist the current screen selection
    if (index >= 0 && index < _branchRoutes.length) {
      final route = _branchRoutes[index];
      final playerState = ref.read(audioPlayerControllerProvider);
      ref.read(statePersistenceServiceProvider).saveState(
        AppSavedState(
          currentSong: playerState.currentSong,
          positionMs: playerState.position.inMilliseconds,
          queue: playerState.queue,
          currentIndex: playerState.currentIndex,
          currentRoute: route,
          recentlyPlayed: playerState.recentlyPlayed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netStatus = ref.watch(connectivityProvider);
    final themeColor = ref.watch(nowPlayingThemeColorProvider);
    final isOffline = netStatus == NetworkStatus.offline;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;

        // 1. Close any open SnackBar first
        ScaffoldMessenger.of(context).clearSnackBars();

        // 2. Check if current branch can pop inner route
        final currentKey = _getNavigatorKeyForBranch(navigationShell.currentIndex);
        if (currentKey?.currentState?.canPop() ?? false) {
          currentKey!.currentState!.pop();
          return;
        }

        // 3. If on another tab (Search, Library, Settings) at root, navigate back to Home first
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return;
        }

        // 4. Otherwise allow app exit
        Navigator.of(context, rootNavigator: true).maybePop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Offline Warning Banner
            if (isOffline)
              Container(
                width: double.infinity,
                color: AppColors.offline,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Offline Mode — Playing downloaded music only',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            Expanded(child: navigationShell),
            // Persistent Mini Player above bottom navigation
            const MiniPlayer(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => _onTabTapped(context, ref, index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primarySkyBlue,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music_outlined),
              activeIcon: Icon(Icons.library_music),
              label: 'Your Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
