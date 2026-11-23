import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Models playback and subtitle preferences.
class PlaybackSettings {
  final bool enableHardwareAcceleration;
  final bool subtitlesEnabled;
  final double subtitleFontSize;

  const PlaybackSettings({
    this.enableHardwareAcceleration = false,
    this.subtitlesEnabled = true,
    this.subtitleFontSize = 22.0,
  });

  PlaybackSettings copyWith({
    bool? enableHardwareAcceleration,
    bool? subtitlesEnabled,
    double? subtitleFontSize,
  }) {
    return PlaybackSettings(
      enableHardwareAcceleration:
          enableHardwareAcceleration ?? this.enableHardwareAcceleration,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
    );
  }
}

/// Manages video playback settings, including hardware vs software rendering,
/// subtitle default visibility, and subtitle font size scaling.
class PlaybackSettingsNotifier extends StateNotifier<PlaybackSettings> {
  static const String _hwKey = 'ani_mobile_hw_accel_v1';
  static const String _subsEnabledKey = 'ani_mobile_subs_enabled_v1';
  static const String _subFontSizeKey = 'ani_mobile_sub_font_size_v1';

  PlaybackSettingsNotifier() : super(const PlaybackSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hw = prefs.getBool(_hwKey) ?? false;
      final subs = prefs.getBool(_subsEnabledKey) ?? true;
      final fontSize = prefs.getDouble(_subFontSizeKey) ?? 22.0;

      state = PlaybackSettings(
        enableHardwareAcceleration: hw,
        subtitlesEnabled: subs,
        subtitleFontSize: fontSize.clamp(14.0, 38.0),
      );
    } catch (_) {}
  }

  Future<void> setHardwareAcceleration(bool enabled) async {
    state = state.copyWith(enableHardwareAcceleration: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hwKey, enabled);
    } catch (_) {}
  }

  Future<void> setSubtitlesEnabled(bool enabled) async {
    state = state.copyWith(subtitlesEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_subsEnabledKey, enabled);
    } catch (_) {}
  }

  Future<void> setSubtitleFontSize(double size) async {
    final clamped = size.clamp(14.0, 38.0);
    state = state.copyWith(subtitleFontSize: clamped);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_subFontSizeKey, clamped);
    } catch (_) {}
  }
}

final playbackSettingsProvider =
    StateNotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>((ref) {
  return PlaybackSettingsNotifier();
});

/// Convenience provider returning whether hardware acceleration is enabled
final hardwareAccelerationProvider = Provider<bool>((ref) {
  return ref.watch(playbackSettingsProvider).enableHardwareAcceleration;
});

/// Convenience provider returning whether subtitles are enabled by default
final subtitlesEnabledProvider = Provider<bool>((ref) {
  return ref.watch(playbackSettingsProvider).subtitlesEnabled;
});

/// Convenience provider returning subtitle font size in pt
final subtitleFontSizeProvider = Provider<double>((ref) {
  return ref.watch(playbackSettingsProvider).subtitleFontSize;
});
