import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/services/state_persistence_service.dart';
import '../../controllers/audio_player_controller.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netStatus = ref.watch(connectivityProvider);
    final themeColor = ref.watch(nowPlayingThemeColorProvider);
    final isOffline = netStatus == NetworkStatus.offline;

    return Scaffold(
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
        onTap: (index) {
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
        },
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'Your Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
