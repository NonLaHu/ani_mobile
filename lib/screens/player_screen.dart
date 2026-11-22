import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import '../models/video_source.dart' hide SubtitleTrack;
import '../providers/download_provider.dart';
import '../providers/playback_settings_provider.dart';
import '../providers/player_provider.dart';
import '../providers/watch_history_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_video_controls.dart';
import '../widgets/download_resolution_sheet.dart';
import '../widgets/loading_cycle.dart';

/// Fullscreen anime video player screen powered by media_kit (libmpv backend).
///
/// Features:
/// - Custom HTTP Referer and User-Agent injection into [Media].
/// - Automated stream fallback if a link is broken or network fails.
/// - Custom video controls with skip-intro (+85s) and episode playlist skipping.
/// - Fullscreen landscape orientation locking with auto-hide overlays.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _lastLoadedUrl;
  bool _isDisposing = false;
  Timer? _seekDebounceTimer;

  @override
  void initState() {
    super.initState();

    // Configure system overlays and landscape orientation for immersive playback
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initPlayer();
  }

  void _initPlayer() {
    // MediaKit Player initialization
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'ani-mobile Player',
        logLevel: MPVLogLevel.error,
        osc: false,
      ),
    );

    // Disable loading external/system lua scripts to prevent libluajit _Unwind_RaiseException crashes on Linux
    try {
      (_player.platform as dynamic)?.setProperty('load-scripts', 'no');
    } catch (_) {}

    final enableHw = ref.read(hardwareAccelerationProvider);
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: enableHw,
      ),
    );

    // Position updates
    _subscriptions.add(
      _player.stream.position.listen((pos) {
        if (!mounted || _isDisposing) return;
        ref.read(playerProvider.notifier).updatePlaybackMetrics(position: pos);
      }),
    );

    // Duration updates
    _subscriptions.add(
      _player.stream.duration.listen((dur) {
        if (!mounted || _isDisposing) return;
        ref.read(playerProvider.notifier).updatePlaybackMetrics(duration: dur);
      }),
    );

    // Buffer updates
    _subscriptions.add(
      _player.stream.buffer.listen((buf) {
        if (!mounted || _isDisposing) return;
        ref.read(playerProvider.notifier).updatePlaybackMetrics(buffer: buf);
      }),
    );

    // Playing state updates
    _subscriptions.add(
      _player.stream.playing.listen((isPlaying) {
        if (!mounted || _isDisposing) return;
        ref.read(playerProvider.notifier).updatePlaybackMetrics(isPlaying: isPlaying);
      }),
    );

    // Buffering state updates
    _subscriptions.add(
      _player.stream.buffering.listen((isBuffering) {
        if (!mounted || _isDisposing) return;
        ref.read(playerProvider.notifier).updatePlaybackMetrics(isBuffering: isBuffering);
      }),
    );

    // Error handling & Automatic Fallback switching
    _subscriptions.add(
      _player.stream.error.listen((err) {
        if (!mounted || _isDisposing) return;
        print('MediaKit Stream Error: $err');
        _handlePlaybackError();
      }),
    );

    // Auto-select subtitle track as soon as tracks become available
    _subscriptions.add(
      _player.stream.tracks.listen((tracks) {
        if (!mounted || _isDisposing) return;
        if (_player.state.track.subtitle == SubtitleTrack.no() && tracks.subtitle.length > 1) {
          final target = tracks.subtitle.firstWhere(
            (t) => (t.language?.toLowerCase().contains('eng') ?? false) ||
                (t.title?.toLowerCase().contains('eng') ?? false),
            orElse: () => tracks.subtitle.firstWhere(
              (t) => t.id != 'no',
              orElse: () => tracks.subtitle.first,
            ),
          );
          if (target.id != 'no') {
            _player.setSubtitleTrack(target);
            print('Auto-enabled subtitle track: ${target.title ?? target.language ?? target.id}');
          }
        }
      }),
    );

    // Auto-advance to next episode when video completes
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (!mounted || _isDisposing) return;
        if (completed) {
          final notifier = ref.read(playerProvider.notifier);
          final playerState = ref.read(playerProvider);
          if (playerState.hasNextEpisode) {
            notifier.playNextEpisode();
          }
        }
      }),
    );
  }

  void _handlePlaybackError() {
    final notifier = ref.read(playerProvider.notifier);
    final switched = notifier.fallbackToNextSource();
    if (!switched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video playback error. Please choose another quality or server.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  final FocusNode _focusNode = FocusNode();

  Future<void> _stopAndExit() async {
    if (_isDisposing) return;
    _isDisposing = true;

    // Persist final position in watch history
    final playerState = ref.read(playerProvider);
    if (playerState.anime != null && playerState.currentEpisode != null) {
      ref.read(watchHistoryProvider.notifier).saveProgress(
            anime: playerState.anime!,
            episode: playerState.currentEpisode!,
            positionSeconds: playerState.position.inSeconds,
            durationSeconds: playerState.duration.inSeconds,
          );
    }

    // Immediately stop and terminate playback
    try {
      await _player.pause();
      await _player.stop();
    } catch (e) {
      print('Error stopping player: $e');
    }

    // Reset player state in Riverpod
    ref.read(playerProvider.notifier).reset();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _loadSourceIntoPlayer(VideoSource source, Duration startPosition) async {
    if (_lastLoadedUrl == source.url) return;
    _lastLoadedUrl = source.url;

    print('Playing stream: ${source.url}');
    print('Injecting HTTP Headers: ${source.headers}');

    // Inject custom headers (User-Agent, Referer, etc.) into Media instance natively
    final media = Media(
      source.url,
      httpHeaders: source.headers,
      start: startPosition > Duration.zero ? startPosition : null,
    );

    await _player.open(media, play: true);

    // Auto-load external subtitle tracks if present
    final state = ref.read(playerProvider);
    final subs = state.streamBundle?.subtitles ?? [];
    if (subs.isNotEmpty) {
      final eng = subs.firstWhere(
        (s) => s.label.toLowerCase().contains('eng'),
        orElse: () => subs.first,
      );
      if (eng.url.isNotEmpty) {
        try {
          await _player.setSubtitleTrack(SubtitleTrack.uri(
            eng.url,
            title: eng.label,
            language: eng.language,
          ));
          print('Auto-loaded external subtitle track: ${eng.label}');
        } catch (e) {
          print('Subtitle track load note: $e');
        }
      }
    } else {
      // For local offline downloads, auto-load matching .vtt or .srt subtitle if present
      if (!source.url.startsWith('http')) {
        final baseFilePath = source.url.replaceAll(RegExp(r'\.(mp4|mkv|ts)$'), '');
        final localVtt = File('$baseFilePath.vtt');
        final localSrt = File('$baseFilePath.srt');
        if (localVtt.existsSync()) {
          try {
            await _player.setSubtitleTrack(SubtitleTrack.uri(
              'file://${localVtt.path}',
              title: 'English (Offline)',
              language: 'eng',
            ));
            print('Auto-loaded local offline subtitle: ${localVtt.path}');
          } catch (e) {
            print('Local subtitle track load note: $e');
          }
        } else if (localSrt.existsSync()) {
          try {
            await _player.setSubtitleTrack(SubtitleTrack.uri(
              'file://${localSrt.path}',
              title: 'English (Offline)',
              language: 'eng',
            ));
            print('Auto-loaded local offline subtitle: ${localSrt.path}');
          } catch (e) {
            print('Local subtitle track load note: $e');
          }
        } else {
          await _player.setSubtitleTrack(SubtitleTrack.auto());
        }
      } else {
        await _player.setSubtitleTrack(SubtitleTrack.auto());
      }
    }
  }

  void _safeSeek(Duration target) {
    if (_isDisposing) return;
    ref.read(playerProvider.notifier).seekTo(target);
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(const Duration(milliseconds: 120), () {
      if (_isDisposing) return;
      _player.seek(target);
    });
  }

  @override
  void dispose() {
    _isDisposing = true;
    _seekDebounceTimer?.cancel();

    // Restore orientation and system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _focusNode.dispose();
    _player.stop();
    _player.dispose();

    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final state = ref.read(playerProvider);

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.keyK) {
      _player.playOrPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyJ) {
      final newPos = state.position - const Duration(seconds: 10);
      final target = newPos > Duration.zero ? newPos : Duration.zero;
      _safeSeek(target);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyL) {
      final newPos = state.position + const Duration(seconds: 10);
      final target = newPos < state.duration ? newPos : state.duration;
      _safeSeek(target);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _stopAndExit();
    } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
      final target = ref.read(playerProvider.notifier).getIntroSkipTarget();
      _safeSeek(target);
    } else if (event.logicalKey == LogicalKeyboardKey.keyN) {
      if (state.hasNextEpisode) {
        ref.read(playerProvider.notifier).playNextEpisode();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyP) {
      if (state.hasPreviousEpisode) {
        ref.read(playerProvider.notifier).playPreviousEpisode();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);

    // When the state source changes or updates, load it into media_kit
    ref.listen<PlayerState>(playerProvider, (previous, next) {
      final nextSrc = next.currentSource;
      final prevSrc = previous?.currentSource;
      if (nextSrc != null && nextSrc.url != prevSrc?.url) {
        _loadSourceIntoPlayer(
          nextSrc,
          next.position,
        );
      }
    });

    // Initial load check if not yet triggered
    if (state.currentSource != null && _lastLoadedUrl == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.currentSource != null) {
          _loadSourceIntoPlayer(state.currentSource!, state.position);
        }
      });
    }

    if (state.currentSource == null && !state.isLoadingStream) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _stopAndExit();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No Video Stream Available',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage ?? 'This episode does not have a playable stream source or has not been uploaded yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Return to Anime'),
                    onPressed: _stopAndExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _stopAndExit();
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Underlying media_kit Video Surface
              Center(
                child: Video(
                  controller: _videoController,
                  controls: (videoState) => const SizedBox.shrink(),
                  subtitleViewConfiguration: const SubtitleViewConfiguration(
                    style: TextStyle(
                      fontSize: 22.0,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(offset: Offset(-1.5, -1.5), color: Colors.black, blurRadius: 4),
                        Shadow(offset: Offset(1.5, -1.5), color: Colors.black, blurRadius: 4),
                        Shadow(offset: Offset(-1.5, 1.5), color: Colors.black, blurRadius: 4),
                        Shadow(offset: Offset(1.5, 1.5), color: Colors.black, blurRadius: 4),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    padding: EdgeInsets.all(24.0),
                  ),
                ),
              ),

              // Central Loading Cycle (shows when loading stream or buffering video)
              if (state.isLoadingStream || state.isBuffering)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                      ),
                      child: LoadingCycle(
                        size: 56,
                        message: state.isLoadingStream
                            ? 'Loading stream'
                            : 'Buffering',
                      ),
                    ),
                  ),
                ),

              // Custom Overlay Controls
              CustomVideoControls(
                playerState: state,
                onTogglePlayPause: () {
                  _player.playOrPause();
                },
                onSeek: (target) {
                  _safeSeek(target);
                },
                onSkipForward10: () {
                  final newPos = state.position + const Duration(seconds: 10);
                  final target = newPos < state.duration ? newPos : state.duration;
                  _safeSeek(target);
                },
                onSkipBackward10: () {
                  final newPos = state.position - const Duration(seconds: 10);
                  final target = newPos > Duration.zero ? newPos : Duration.zero;
                  _safeSeek(target);
                },
                onSkipIntro: () {
                  final target = ref.read(playerProvider.notifier).getIntroSkipTarget();
                  _safeSeek(target);
                },
                onPlayNext: () {
                  ref.read(playerProvider.notifier).playNextEpisode();
                },
                onPlayPrevious: () {
                  ref.read(playerProvider.notifier).playPreviousEpisode();
                },
                onSelectSource: (source) {
                  ref.read(playerProvider.notifier).selectSource(source);
                },
                onRetrySource: () {
                  if (state.currentSource != null) {
                    _loadSourceIntoPlayer(state.currentSource!, state.position);
                  }
                },
                onBack: _stopAndExit,
                onDownload: () {
                  if (state.anime != null && state.currentEpisode != null) {
                    DownloadResolutionSheet.show(
                      context,
                      anime: state.anime!,
                      episode: state.currentEpisode!,
                      preloadedBundle: state.streamBundle,
                      onQualitySelected: (chosenSource, subUrl) {
                        ref.read(downloadProvider.notifier).startDownload(
                              anime: state.anime!,
                              episode: state.currentEpisode!,
                              preselectedSource: chosenSource,
                              preselectedSubtitleUrl: subUrl,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.downloading_rounded, color: AppTheme.accentCyan, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('Downloading Episode ${state.currentEpisode!.number} (${chosenSource.quality}) with subtitles...'),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF2C243B),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
