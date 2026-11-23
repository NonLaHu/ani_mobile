import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/update/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

/// Tracks whether startup realtime update check has already run in the current session.
final startupUpdateCheckedProvider = StateProvider<bool>((ref) => false);

/// Controller helper for checking updates both on app start and manually from Settings.
class UpdateController {
  /// Checks for updates silently on app startup.
  ///
  /// Strictly silent if up-to-date or if offline/error occurs.
  /// Only displays a dialog when an update is actually available.
  static Future<void> checkStartupUpdateSilently(
    BuildContext context,
    WidgetRef ref, {
    bool forceMock = false,
  }) async {
    final alreadyChecked = ref.read(startupUpdateCheckedProvider);
    if (alreadyChecked) return;
    ref.read(startupUpdateCheckedProvider.notifier).state = true;

    try {
      final service = ref.read(updateServiceProvider);
      final info = await service.checkForUpdates(forceMockUpdate: forceMock);
      if (info.hasUpdate && context.mounted) {
        await UpdateService.showUpdateDialog(context, info);
      }
    } catch (_) {
      // Intentionally silent as per requirement
    }
  }

  /// Checks for updates when explicitly triggered by the user in SettingsScreen.
  static Future<void> checkManualUpdate(
    BuildContext context,
    WidgetRef ref, {
    bool forceMock = false,
  }) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking for updates...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final service = ref.read(updateServiceProvider);
      final info = await service.checkForUpdates(forceMockUpdate: forceMock);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (info.hasUpdate) {
        await UpdateService.showUpdateDialog(context, info);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are on the latest version (v${info.currentVersion}).'),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not check for updates: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }
}
