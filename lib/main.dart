import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/navigation/app_router.dart';
import 'controllers/auth_controller.dart';
import 'core/network/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: SpotifyApp(),
    ),
  );
}

class SpotifyApp extends ConsumerWidget {
  const SpotifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = createRouter(true);

    return MaterialApp.router(
      title: 'SkyTune',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
