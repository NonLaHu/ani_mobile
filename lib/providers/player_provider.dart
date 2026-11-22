import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../models/video_source.dart';
import 'anime_details_provider.dart';
import 'scraper_provider.dart';
import 'watch_history_provider.dart';

/// Immutable state holding active player status, sources, and playback metrics
class PlayerState {
  final Anime? anime;
  final Episode? currentEpisode;
  final List<Episode> playlist;
  final StreamBundle? streamBundle;
  final VideoSource? currentSource;
  final bool isLoadingStream;
  final String? errorMessage;
  final String? infoMessage;
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final bool isPlaying;
  final bool isControlsVisible;
  final double playbackSpeed;

  const PlayerState({
    this.anime,
    this.currentEpisode,
    this.playlist = const [],
    this.streamBundle,
    this.currentSource,
    this.isLoadingStream = false,
    this.errorMessage,
    this.infoMessage,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffer = Duration.zero,
    this.isPlaying = false,
    this.isControlsVisible = true,
    this.playbackSpeed = 1.0,
  });

  bool get hasNextEpisode {
    if (currentEpisode == null || playlist.isEmpty) return false;
    final idx = playlist.indexWhere((e) => e.id == currentEpisode!.id);
    return idx >= 0 && idx + 1 < playlist.length;
  }

  bool get hasPreviousEpisode {
    if (currentEpisode == null || playlist.isEmpty) return false;
    final idx = playlist.indexWhere((e) => e.id == currentEpisode!.id);
    return idx > 0;
  }

  Episode? get nextEpisode {
    if (!hasNextEpisode) return null;
    final idx = playlist.indexWhere((e) => e.id == currentEpisode!.id);
    return playlist[idx + 1];
  }

  Episode? get previousEpisode {
    if (!hasPreviousEpisode) return null;
    final idx = playlist.indexWhere((e) => e.id == currentEpisode!.id);
    return playlist[idx - 1];
  }

  bool get canSkipIntro {
    if (streamBundle?.introStart == null || streamBundle?.introEnd == null) {
      // Fallback: allow 85s skip during first 2 minutes
      return position.inSeconds < 120;
    }
    final posSec = position.inSeconds;
    return posSec >= streamBundle!.introStart! && posSec < streamBundle!.introEnd!;
  }

  PlayerState copyWith({
    Anime? anime,
    Episode? currentEpisode,
    List<Episode>? playlist,
    StreamBundle? streamBundle,
    VideoSource? currentSource,
    bool? isLoadingStream,
    String? errorMessage,
    String? infoMessage,
    Duration? position,
    Duration? duration,
    Duration? buffer,
    bool? isPlaying,
    bool? isControlsVisible,
    double? playbackSpeed,
  }) {
    return PlayerState(
      anime: anime ?? this.anime,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      playlist: playlist ?? this.playlist,
      streamBundle: streamBundle ?? this.streamBundle,
      currentSource: currentSource ?? this.currentSource,
      isLoadingStream: isLoadingStream ?? this.isLoadingStream,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffer: buffer ?? this.buffer,
      isPlaying: isPlaying ?? this.isPlaying,
      isControlsVisible: isControlsVisible ?? this.isControlsVisible,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}

/// Riverpod StateNotifier controlling stream loading, source switching, and fallback logic
class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref ref;

  PlayerNotifier(this.ref) : super(const PlayerState());

  /// Sets up playback for a selected episode within an anime
  Future<void> setupEpisode({
    required Anime anime,
    required Episode episode,
    required List<Episode> playlist,
    int? resumePositionSeconds,
  }) async {
    state = state.copyWith(
      anime: anime,
      currentEpisode: episode,
      playlist: playlist,
      isLoadingStream: true,
      errorMessage: null,
      infoMessage: null,
      position: Duration(seconds: resumePositionSeconds ?? 0),
    );

    await _fetchStreams(episode);
  }

  Future<void> _fetchStreams(Episode episode) async {
    try {
      final scraper = ref.read(scraperServiceProvider);
      final bundle = await scraper.getStreamSources(episode.id);

      if (bundle.sources.isEmpty) {
        state = state.copyWith(
          isLoadingStream: false,
          errorMessage: 'No playable video sources found for this episode.',
        );
        return;
      }

      final preferredQuality = ref.read(preferredQualityProvider);
      final preferred = bundle.getPreferredSource(preferredQuality) ?? bundle.sources.first;

      state = state.copyWith(
        streamBundle: bundle,
        currentSource: preferred,
        isLoadingStream: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingStream: false,
        errorMessage: 'Failed to extract stream: ${e.toString()}',
      );
    }
  }

  /// Manually switch video quality or server
  void selectSource(VideoSource newSource) {
    if (newSource.url == state.currentSource?.url) return;
    state = state.copyWith(
      currentSource: newSource,
      infoMessage: 'Switched to ${newSource.quality} (${newSource.serverName})',
    );
  }

  /// Fallback to next available quality/server when current source fails to play
  bool fallbackToNextSource() {
    final bundle = state.streamBundle;
    final current = state.currentSource;
    if (bundle == null || current == null) return false;

    final nextSource = bundle.getNextFallbackSource(current);
    if (nextSource != null) {
      state = state.copyWith(
        currentSource: nextSource,
        infoMessage:
            'Source failed. Falling back to ${nextSource.quality} (${nextSource.serverName})...',
      );
      return true;
    }
    state = state.copyWith(
      errorMessage: 'All available streaming sources failed for this episode.',
    );
    return false;
  }

  /// Advances to next episode in playlist
  Future<void> playNextEpisode() async {
    final next = state.nextEpisode;
    if (next != null && state.anime != null) {
      await setupEpisode(
        anime: state.anime!,
        episode: next,
        playlist: state.playlist,
      );
    }
  }

  /// Rewinds to previous episode in playlist
  Future<void> playPreviousEpisode() async {
    final prev = state.previousEpisode;
    if (prev != null && state.anime != null) {
      await setupEpisode(
        anime: state.anime!,
        episode: prev,
        playlist: state.playlist,
      );
    }
  }

  /// Updates live playback indicators from the media_kit controller
  void updatePlaybackMetrics({
    Duration? position,
    Duration? duration,
    Duration? buffer,
    bool? isPlaying,
  }) {
    state = state.copyWith(
      position: position,
      duration: duration,
      buffer: buffer,
      isPlaying: isPlaying,
    );

    // Save progress to watch history every ~10 seconds
    if (position != null &&
        duration != null &&
        state.anime != null &&
        state.currentEpisode != null &&
        position.inSeconds % 10 == 0) {
      ref.read(watchHistoryProvider.notifier).saveProgress(
            anime: state.anime!,
            episode: state.currentEpisode!,
            positionSeconds: position.inSeconds,
            durationSeconds: duration.inSeconds,
          );
    }
  }

  /// Toggles visibility of onscreen overlay controls
  void toggleControls() {
    state = state.copyWith(isControlsVisible: !state.isControlsVisible);
  }

  void setControlsVisible(bool visible) {
    if (state.isControlsVisible != visible) {
      state = state.copyWith(isControlsVisible: visible);
    }
  }

  void clearMessages() {
    state = state.copyWith(errorMessage: null, infoMessage: null);
  }

  /// Computes target skip position for anime intro (85 seconds default or scraped timestamp)
  Duration getIntroSkipTarget() {
    if (state.streamBundle?.introEnd != null) {
      return Duration(seconds: state.streamBundle!.introEnd!);
    }
    return state.position + const Duration(seconds: 85);
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});
