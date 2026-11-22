import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages video playback settings, including hardware vs software rendering.
///
/// Hardware acceleration defaults to `false` (Software rendering) to prevent
/// blue-screen rendering bugs under Linux Impeller OpenGL with libmpv TextureGL.
class PlaybackSettingsNotifier extends StateNotifier<bool> {
  static const String _hwKey = 'ani_mobile_hw_accel_v1';

  PlaybackSettingsNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_hwKey) ?? false;
    } catch (_) {}
  }

  Future<void> setHardwareAcceleration(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hwKey, enabled);
    } catch (_) {}
  }
}

final hardwareAccelerationProvider =
    StateNotifierProvider<PlaybackSettingsNotifier, bool>((ref) {
  return PlaybackSettingsNotifier();
});
