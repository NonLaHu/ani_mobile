import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../models/video_source.dart';
import '../services/download/download_service.dart';
import '../services/scraper/anime_scraper_service.dart';
import '../services/scraper/live_scraper_service.dart';
import 'anime_details_provider.dart';
import 'download_provider.dart';
import 'playback_settings_provider.dart';
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
  final bool isBuffering;
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
    this.isBuffering = false,
    this.isControlsVisible = true,
    this.playbackSpeed = 1.0,
  });

  /// Identifies if the current media is a local offline file
  bool get isOfflineMode {
    final s = currentSource;
    if (s == null) return false;
    return s.serverName == 'Downloaded File' ||
        s.serverName == 'Local Storage' ||
        !s.url.startsWith('http');
  }

  /// Locates index of current episode in playlist by ID or episode number
  int get currentEpisodeIndex {
    if (currentEpisode == null || playlist.isEmpty) return -1;
    final idx = playlist.indexWhere((e) => e.id == currentEpisode!.id);
    if (idx != -1) return idx;
    return playlist.indexWhere((e) =>
        e.number == currentEpisode!.number &&
        (e.isDub == currentEpisode!.isDub || e.id == currentEpisode!.id));
  }

  bool get hasNextEpisode {
    if (currentEpisode == null) return false;
    final idx = currentEpisodeIndex;
    if (idx >= 0 && idx + 1 < playlist.length) return true;
    // In offline mode, allow clicking next to search download folder for the next episode
    if (isOfflineMode) return true;
    return false;
  }

  bool get hasPreviousEpisode {
    if (currentEpisode == null) return false;
    final idx = currentEpisodeIndex;
    if (idx > 0) return true;
    if (isOfflineMode && currentEpisode!.number > 1) return true;
    return false;
  }

  Episode? get nextEpisode {
    final idx = currentEpisodeIndex;
    if (idx >= 0 && idx + 1 < playlist.length) {
      return playlist[idx + 1];
    }
    return null;
  }

  Episode? get previousEpisode {
    final idx = currentEpisodeIndex;
    if (idx > 0 && idx - 1 < playlist.length) {
      return playlist[idx - 1];
    }
    return null;
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
    bool? isBuffering,
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
      isBuffering: isBuffering ?? this.isBuffering,
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
  Future<bool> setupEpisode({
    required Anime anime,
    required Episode episode,
    required List<Episode> playlist,
    int? resumePositionSeconds,
  }) async {
    final initialPos = Duration(seconds: resumePositionSeconds ?? 0);
    state = state.copyWith(
      anime: anime,
      currentEpisode: episode,
      playlist: playlist,
      isLoadingStream: true,
      errorMessage: null,
      infoMessage: null,
      position: initialPos,
      duration: Duration.zero,
      buffer: Duration.zero,
    );

    return await _fetchStreams(episode, initialPosition: initialPos);
  }

  /// Sets up playback for a downloaded offline episode
  void setupOfflineEpisode({
    required Anime anime,
    required Episode episode,
    required List<Episode> playlist,
    required VideoSource source,
    int? resumePositionSeconds,
  }) {
    List<Episode> effectivePlaylist = List.from(playlist);

    // Auto-discover and populate all downloaded episodes for this anime if playlist is empty or single-item
    if (effectivePlaylist.length <= 1) {
      final diskFiles = ref.read(downloadProvider).diskFiles;
      final normTitle = DownloadState.normalizeTitle(anime.title);
      final matching = diskFiles
          .where((df) => DownloadState.normalizeTitle(df.animeTitle) == normTitle)
          .toList()
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

      if (matching.isNotEmpty) {
        effectivePlaylist = matching
            .map((df) => Episode(
                  id: df.file.path,
                  animeId: anime.id,
                  number: df.episodeNumber,
                  title: 'Episode ${df.episodeNumber}',
                  isDub: df.isDub,
                  isSub: !df.isDub,
                ))
            .toList();
      }
    }

    final bundle = StreamBundle(
      episodeId: episode.id,
      animeId: anime.id,
      episodeNumber: episode.number,
      sources: [source],
    );

    state = PlayerState(
      anime: anime,
      currentEpisode: episode,
      playlist: effectivePlaylist,
      streamBundle: bundle,
      currentSource: source,
      isLoadingStream: false,
      position: Duration(seconds: resumePositionSeconds ?? 0),
      duration: Duration.zero,
      buffer: Duration.zero,
    );
  }

  Future<bool> _fetchStreams(Episode episode, {Duration? initialPosition}) async {
    try {
      final scraper = ref.read(scraperServiceProvider);
      StreamBundle bundle;
      try {
        bundle = await scraper.getStreamSources(episode.id, dub: episode.isDub);
      } catch (err) {
        if (err is EpisodeNotAvailableException) {
          rethrow;
        }
        if (scraper is! LiveScraperService) {
          print('Primary scraper stream failed ($err). Falling back to LiveScraperService...');
          final fallbackScraper = LiveScraperService();
          bundle = await fallbackScraper.getStreamSources(episode.id, dub: episode.isDub);
        } else {
          rethrow;
        }
      }

      if (bundle.sources.isEmpty) {
        state = state.copyWith(
          isLoadingStream: false,
          errorMessage:
              'This episode has not been uploaded yet or has no playable stream sources. Try turning on a VPN if you think it has already aired.',
        );
        return false;
      }

      final preferredQuality = ref.read(preferredQualityProvider);
      final preferred = bundle.getPreferredSource(preferredQuality) ?? bundle.sources.first;

      state = state.copyWith(
        streamBundle: bundle,
        currentSource: preferred,
        isLoadingStream: false,
        errorMessage: null,
        position: initialPosition ?? Duration.zero,
        duration: Duration.zero,
        buffer: Duration.zero,
      );
      return true;
    } catch (e) {
      final message = e is EpisodeNotAvailableException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isLoadingStream: false,
        errorMessage: message,
      );
      return false;
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

  /// Searches for a downloaded episode in the ani_mobile offline folder and tracked disk files
  Future<DiskVideoFile?> findOfflineEpisode(String animeTitle, int episodeNumber, {bool? isDub}) async {
    final normSearch = DownloadState.normalizeTitle(animeTitle);

    // 1. Check in-memory disk files list
    final currentDiskFiles = ref.read(downloadProvider).diskFiles;
    for (final df in currentDiskFiles) {
      if (df.episodeNumber == episodeNumber &&
          (isDub == null || df.isDub == isDub) &&
          DownloadState.normalizeTitle(df.animeTitle) == normSearch &&
          df.file.existsSync() &&
          df.file.lengthSync() > 0) {
        return df;
      }
    }

    // Check with relaxed dub matching if specific variant not found
    for (final df in currentDiskFiles) {
      if (df.episodeNumber == episodeNumber &&
          DownloadState.normalizeTitle(df.animeTitle) == normSearch &&
          df.file.existsSync() &&
          df.file.lengthSync() > 0) {
        return df;
      }
    }

    // 2. Scan physical download folder directly
    try {
      final scannedFiles = await ref.read(downloadServiceProvider).scanDownloadedFiles();
      for (final df in scannedFiles) {
        if (df.episodeNumber == episodeNumber &&
            (isDub == null || df.isDub == isDub) &&
            DownloadState.normalizeTitle(df.animeTitle) == normSearch &&
            df.file.existsSync() &&
            df.file.lengthSync() > 0) {
          return df;
        }
      }
      for (final df in scannedFiles) {
        if (df.episodeNumber == episodeNumber &&
            DownloadState.normalizeTitle(df.animeTitle) == normSearch &&
            df.file.existsSync() &&
            df.file.lengthSync() > 0) {
          return df;
        }
      }
    } catch (e) {
      print('Error scanning offline folder for episode: $e');
    }

    return null;
  }

  /// Searches for any higher episode downloaded offline (e.g. jumping from Ep 1 to Ep 3)
  Future<DiskVideoFile?> findNextAvailableOfflineEpisode(String animeTitle, int currentEpNumber) async {
    final normSearch = DownloadState.normalizeTitle(animeTitle);
    final currentDiskFiles = ref.read(downloadProvider).diskFiles;

    final matching = currentDiskFiles
        .where((df) =>
            DownloadState.normalizeTitle(df.animeTitle) == normSearch &&
            df.episodeNumber > currentEpNumber &&
            df.file.existsSync() &&
            df.file.lengthSync() > 0)
        .toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

    if (matching.isNotEmpty) {
      return matching.first;
    }

    try {
      final scannedFiles = await ref.read(downloadServiceProvider).scanDownloadedFiles();
      final scannedMatching = scannedFiles
          .where((df) =>
              DownloadState.normalizeTitle(df.animeTitle) == normSearch &&
              df.episodeNumber > currentEpNumber &&
              df.file.existsSync() &&
              df.file.lengthSync() > 0)
          .toList()
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

      if (scannedMatching.isNotEmpty) {
        return scannedMatching.first;
      }
    } catch (_) {}

    return null;
  }

  /// Advances to next episode in playlist or searches offline downloads folder
  Future<void> playNextEpisode() async {
    final currentEp = state.currentEpisode;
    final anime = state.anime;
    if (currentEp == null || anime == null) return;

    // Immediately flag loading & reset position to zero so new episode starts cleanly at 0:00
    state = state.copyWith(
      isLoadingStream: true,
      position: Duration.zero,
      duration: Duration.zero,
      buffer: Duration.zero,
      errorMessage: null,
      infoMessage: null,
    );

    final isOffline = state.isOfflineMode;
    final nextEpNumber = currentEp.number + 1;
    Episode? targetNext = state.nextEpisode;

    // 1. Search the offline download folder on disk for the next episode
    final offlineMatch = await findOfflineEpisode(anime.title, nextEpNumber, isDub: currentEp.isDub);

    if (offlineMatch != null) {
      final nextEpisode = targetNext ??
          Episode(
            id: offlineMatch.file.path,
            animeId: anime.id,
            number: offlineMatch.episodeNumber,
            title: 'Episode ${offlineMatch.episodeNumber}',
            isDub: offlineMatch.isDub,
            isSub: !offlineMatch.isDub,
          );

      final offlineSource = VideoSource(
        url: offlineMatch.file.path,
        quality: 'Offline (${offlineMatch.formattedSize})',
        isHls: false,
        serverName: 'Downloaded File',
      );

      List<Episode> updatedPlaylist = List.from(state.playlist);
      if (!updatedPlaylist.any((e) => e.number == nextEpisode.number && e.isDub == nextEpisode.isDub)) {
        updatedPlaylist.add(nextEpisode);
        updatedPlaylist.sort((a, b) => a.number.compareTo(b.number));
      }

      setupOfflineEpisode(
        anime: anime,
        episode: nextEpisode,
        playlist: updatedPlaylist,
        source: offlineSource,
        resumePositionSeconds: 0,
      );
      return;
    }

    // 2. If no exact match for nextEpNumber, check if any higher episode exists offline (e.g. Ep 1 to Ep 3)
    if (isOffline) {
      final higherOfflineMatch = await findNextAvailableOfflineEpisode(anime.title, currentEp.number);
      if (higherOfflineMatch != null) {
        final nextEpisode = Episode(
          id: higherOfflineMatch.file.path,
          animeId: anime.id,
          number: higherOfflineMatch.episodeNumber,
          title: 'Episode ${higherOfflineMatch.episodeNumber}',
          isDub: higherOfflineMatch.isDub,
          isSub: !higherOfflineMatch.isDub,
        );

        final offlineSource = VideoSource(
          url: higherOfflineMatch.file.path,
          quality: 'Offline (${higherOfflineMatch.formattedSize})',
          isHls: false,
          serverName: 'Downloaded File',
        );

        List<Episode> updatedPlaylist = List.from(state.playlist);
        if (!updatedPlaylist.any((e) => e.number == nextEpisode.number && e.isDub == nextEpisode.isDub)) {
          updatedPlaylist.add(nextEpisode);
          updatedPlaylist.sort((a, b) => a.number.compareTo(b.number));
        }

        setupOfflineEpisode(
          anime: anime,
          episode: nextEpisode,
          playlist: updatedPlaylist,
          source: offlineSource,
          resumePositionSeconds: 0,
        );
        return;
      }

      // Offline mode and no more offline episodes on disk
      if (targetNext != null) {
        // Try streaming online if target exists in playlist
        final ok = await setupEpisode(
          anime: anime,
          episode: targetNext,
          playlist: state.playlist,
          resumePositionSeconds: 0,
        );
        if (!ok) {
          state = state.copyWith(
            isLoadingStream: false,
            errorMessage: 'Episode $nextEpNumber is not downloaded offline, and stream loading failed.',
          );
        }
        return;
      }

      state = state.copyWith(
        isLoadingStream: false,
        infoMessage: 'No further downloaded episodes found in the offline folder.',
      );
      return;
    }

    // 3. Online mode fallback: load next episode and ensure position starts at 0:00
    if (targetNext != null) {
      await setupEpisode(
        anime: anime,
        episode: targetNext,
        playlist: state.playlist,
        resumePositionSeconds: 0,
      );
    } else {
      state = state.copyWith(
        isLoadingStream: false,
        infoMessage: 'Reached the end of the episode list.',
      );
    }
  }

  /// Rewinds to previous episode in playlist or searches offline downloads folder
  Future<void> playPreviousEpisode() async {
    final currentEp = state.currentEpisode;
    final anime = state.anime;
    if (currentEp == null || anime == null) return;

    state = state.copyWith(
      isLoadingStream: true,
      position: Duration.zero,
      duration: Duration.zero,
      buffer: Duration.zero,
      errorMessage: null,
      infoMessage: null,
    );

    final prevEpNumber = currentEp.number - 1;
    Episode? targetPrev = state.previousEpisode;

    if (prevEpNumber >= 1) {
      final offlineMatch = await findOfflineEpisode(anime.title, prevEpNumber, isDub: currentEp.isDub);
      if (offlineMatch != null) {
        final prevEpisode = targetPrev ??
            Episode(
              id: offlineMatch.file.path,
              animeId: anime.id,
              number: offlineMatch.episodeNumber,
              title: 'Episode ${offlineMatch.episodeNumber}',
              isDub: offlineMatch.isDub,
              isSub: !offlineMatch.isDub,
            );

        final offlineSource = VideoSource(
          url: offlineMatch.file.path,
          quality: 'Offline (${offlineMatch.formattedSize})',
          isHls: false,
          serverName: 'Downloaded File',
        );

        List<Episode> updatedPlaylist = List.from(state.playlist);
        if (!updatedPlaylist.any((e) => e.number == prevEpisode.number && e.isDub == prevEpisode.isDub)) {
          updatedPlaylist.add(prevEpisode);
          updatedPlaylist.sort((a, b) => a.number.compareTo(b.number));
        }

        setupOfflineEpisode(
          anime: anime,
          episode: prevEpisode,
          playlist: updatedPlaylist,
          source: offlineSource,
          resumePositionSeconds: 0,
        );
        return;
      }
    }

    if (targetPrev != null) {
      await setupEpisode(
        anime: anime,
        episode: targetPrev,
        playlist: state.playlist,
        resumePositionSeconds: 0,
      );
    } else {
      state = state.copyWith(
        isLoadingStream: false,
        infoMessage: 'No previous episode available.',
      );
    }
  }

  /// Updates live playback indicators from the media_kit controller
  void updatePlaybackMetrics({
    Duration? position,
    Duration? duration,
    Duration? buffer,
    bool? isPlaying,
    bool? isBuffering,
  }) {
    // If a new stream or episode is loading, ignore metrics from the terminating player
    if (state.isLoadingStream) {
      return;
    }

    state = state.copyWith(
      position: position,
      duration: duration,
      buffer: buffer,
      isPlaying: isPlaying,
      isBuffering: isBuffering,
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

  /// Sets state position immediately when seeking to prevent UI jitter
  void seekTo(Duration target) {
    state = state.copyWith(position: target);
  }

  /// Resets player provider state completely when leaving the player screen
  void reset() {
    state = const PlayerState();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});
