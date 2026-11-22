import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/notification/notification_service.dart';
import 'theme/app_theme.dart';

void main() {
  // Ensure Flutter engine bindings are initialized before accessing plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit native libraries (libmpv backend)
  // This enables cross-platform hardware-accelerated video decoding with custom HTTP headers
  MediaKit.ensureInitialized();

  // Initialize local notifications in background
  NotificationService().init();

  runApp(
    // ProviderScope is required for Riverpod state management
    const ProviderScope(
      child: AniMobileApp(),
    ),
  );
}

class AniMobileApp extends ConsumerWidget {
  const AniMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'ani-mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
