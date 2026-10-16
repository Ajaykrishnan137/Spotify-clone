import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/navigation/app_router.dart';
import 'controllers/auth_controller.dart';
import 'core/network/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client
  try {
    await SupabaseConfig.initialize();
  } catch (_) {
    // Graceful offline fallback if keys not configured during test runs
  }

  runApp(
    const ProviderScope(
      child: WavelyApp(),
    ),
  );
}

class WavelyApp extends ConsumerWidget {
  const WavelyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final router = createRouter(authState.isAuthenticated);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
