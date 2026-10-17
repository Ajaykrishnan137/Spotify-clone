import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/services/state_persistence_service.dart';
import 'controllers/audio_player_controller.dart';
import 'views/navigation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AudioService as an Android foreground service with SkyTune notification channel
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.skytune.music.channel.audio',
      androidNotificationChannelName: 'SkyTune Playback',
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
      child: SkyTuneApp(initialRoute: initialRoute),
    ),
  );
}

class SkyTuneApp extends StatefulWidget {
  final String initialRoute;

  const SkyTuneApp({super.key, this.initialRoute = '/home'});

  @override
  State<SkyTuneApp> createState() => _SkyTuneAppState();
}

class _SkyTuneAppState extends State<SkyTuneApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        title: 'SkyTune',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: SplashScreen(
          onFinish: () {
            setState(() {
              _showSplash = false;
            });
          },
        ),
      );
    }

    final router = createRouter(initialLocation: widget.initialRoute);

    return MaterialApp.router(
      title: 'SkyTune',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
