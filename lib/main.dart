import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/services/state_persistence_service.dart';
import 'controllers/audio_player_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AudioService as an Android foreground service with a persistent notification
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.wavely.music.channel.audio',
      androidNotificationChannelName: 'Wavely Music Playback',
      androidNotificationChannelDescription: 'Active background playback controls and notification shade widget',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      androidNotificationClickStartsActivity: true,
    ),
  );

  // Load saved navigation route and player state
  final persistenceService = StatePersistenceService();
  final savedState = await persistenceService.loadState();
  final initialRoute = savedState?.currentRoute ?? '/home';

  runApp(
    ProviderScope(
      overrides: [
        audioPlayerHandlerProvider.overrideWithValue(audioHandler as AudioPlayerHandler),
      ],
      child: SpotifyApp(initialRoute: initialRoute),
    ),
  );
}

class SpotifyApp extends ConsumerWidget {
  final String initialRoute;

  const SpotifyApp({super.key, this.initialRoute = '/home'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = createRouter(initialLocation: initialRoute);

    return MaterialApp.router(
      title: 'SkyTune',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
