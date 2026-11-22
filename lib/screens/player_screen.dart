import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import '../models/video_source.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../providers/watch_history_provider.dart';
import '../widgets/custom_video_controls.dart';

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

    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
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

    // Error handling & Automatic Fallback switching
    _subscriptions.add(
      _player.stream.error.listen((err) {
        if (!mounted || _isDisposing) return;
        print('MediaKit Stream Error: $err');
        _handlePlaybackError();
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

  void _loadSourceIntoPlayer(VideoSource source, Duration startPosition) {
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

    _player.open(media, play: true);
  }

  @override
  void dispose() {
    _isDisposing = true;

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
      ref.read(playerProvider.notifier).seekTo(target);
      _player.seek(target);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyL) {
      final newPos = state.position + const Duration(seconds: 10);
      final target = newPos < state.duration ? newPos : state.duration;
      ref.read(playerProvider.notifier).seekTo(target);
      _player.seek(target);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _stopAndExit();
    } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
      final target = ref.read(playerProvider.notifier).getIntroSkipTarget();
      ref.read(playerProvider.notifier).seekTo(target);
      _player.seek(target);
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
                ),
              ),

              // Custom Overlay Controls
              CustomVideoControls(
                playerState: state,
                onTogglePlayPause: () {
                  _player.playOrPause();
                },
                onSeek: (target) {
                  ref.read(playerProvider.notifier).seekTo(target);
                  _player.seek(target);
                },
                onSkipForward10: () {
                  final newPos = state.position + const Duration(seconds: 10);
                  final target = newPos < state.duration ? newPos : state.duration;
                  ref.read(playerProvider.notifier).seekTo(target);
                  _player.seek(target);
                },
                onSkipBackward10: () {
                  final newPos = state.position - const Duration(seconds: 10);
                  final target = newPos > Duration.zero ? newPos : Duration.zero;
                  ref.read(playerProvider.notifier).seekTo(target);
                  _player.seek(target);
                },
                onSkipIntro: () {
                  final target = ref.read(playerProvider.notifier).getIntroSkipTarget();
                  ref.read(playerProvider.notifier).seekTo(target);
                  _player.seek(target);
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
                  if (state.anime != null && state.currentEpisode != null && state.currentSource != null) {
                    ref.read(downloadProvider.notifier).startDownload(
                          anime: state.anime!,
                          episode: state.currentEpisode!,
                          preselectedSource: state.currentSource,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloading Episode ${state.currentEpisode!.number}...'),
                        duration: const Duration(seconds: 2),
                      ),
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
