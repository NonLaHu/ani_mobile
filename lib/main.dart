import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  // Ensure Flutter engine bindings are initialized before accessing plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit native libraries (libmpv backend)
  // This enables cross-platform hardware-accelerated video decoding with custom HTTP headers
  MediaKit.ensureInitialized();

  runApp(
    // ProviderScope is required for Riverpod state management
    const ProviderScope(
      child: AniMobileApp(),
    ),
  );
}

class AniMobileApp extends StatelessWidget {
  const AniMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ani-mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
