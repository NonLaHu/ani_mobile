import 'dart:async';
import 'package:flutter/material.dart';
import '../models/video_source.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import 'loading_cycle.dart';
import 'quality_selector_sheet.dart';

/// Comprehensive custom on-screen video controls overlay for PlayerScreen.
class CustomVideoControls extends StatefulWidget {
  final PlayerState playerState;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSkipForward10;
  final VoidCallback onSkipBackward10;
  final VoidCallback onSkipIntro;
  final VoidCallback onPlayNext;
  final VoidCallback onPlayPrevious;
  final ValueChanged<VideoSource> onSelectSource;
  final VoidCallback onRetrySource;
  final VoidCallback onBack;
  final VoidCallback? onDownload;

  const CustomVideoControls({
    super.key,
    required this.playerState,
    required this.onTogglePlayPause,
    required this.onSeek,
    required this.onSkipForward10,
    required this.onSkipBackward10,
    required this.onSkipIntro,
    required this.onPlayNext,
    required this.onPlayPrevious,
    required this.onSelectSource,
    required this.onRetrySource,
    required this.onBack,
    this.onDownload,
  });

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  bool _isDraggingSlider = false;
  double _sliderDragValue = 0.0;
  bool _isSeeking = false;
  Timer? _seekDebounceTimer;
  Timer? _hideTimer;
  bool _visible = true;
  String? _quickSeekLabel;
  Timer? _quickSeekTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekDebounceTimer?.cancel();
    _quickSeekTimer?.cancel();
    super.dispose();
  }

  void _showQuickSeekFeedback({required bool isForward}) {
    setState(() {
      _quickSeekLabel = isForward ? '+10s' : '-10s';
    });
    _quickSeekTimer?.cancel();
    _quickSeekTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _quickSeekLabel = null);
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (widget.playerState.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_isDraggingSlider) {
          setState(() => _visible = false);
        }
      });
    }
  }

  void _onUserInteraction() {
    setState(() => _visible = true);
    _startHideTimer();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.playerState;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _visible = !_visible);
        if (_visible) _startHideTimer();
      },
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: !_visible,
          child: Container(
            color: Colors.black45,
            child: Stack(
              children: [
                // Double tap skip zones
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: () {
                            widget.onSkipBackward10();
                            _showQuickSeekFeedback(isForward: false);
                          },
                        ),
                      ),
                      const SizedBox(width: 140),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: () {
                            widget.onSkipForward10();
                            _showQuickSeekFeedback(isForward: true);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick seek feedback badge
                if (_quickSeekLabel != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.accentCyan, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentCyan.withOpacity(0.3),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _quickSeekLabel!.contains('+')
                                ? Icons.fast_forward_rounded
                                : Icons.fast_rewind_rounded,
                            color: AppTheme.accentCyan,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _quickSeekLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top Action Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(context, state),
                ),

                // Center Play/Skip Controls
                Center(
                  child: _buildCenterControls(state),
                ),

                // Bottom Controls & Seeker
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomBar(context, state),
                ),

                // Skip Intro Button (ani-mobile inspired quick skip)
                if (state.canSkipIntro)
                  Positioned(
                    bottom: 90,
                    right: 24,
                    child: _buildSkipIntroButton(),
                  ),

                // Info / Fallback Notification Banner
                if (state.infoMessage != null)
                  Positioned(
                    top: 70,
                    left: 20,
                    right: 20,
                    child: _buildNotificationBanner(
                      state.infoMessage!,
                      Colors.cyanAccent,
                    ),
                  ),

                // Error Banner with Retry
                if (state.errorMessage != null)
                  Positioned(
                    top: 70,
                    left: 20,
                    right: 20,
                    child: _buildErrorBanner(state.errorMessage!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, PlayerState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
            onPressed: () {
              widget.onBack();
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.anime?.title ?? 'Anime Player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  state.currentEpisode != null
                      ? 'Episode ${state.currentEpisode!.number}: ${state.currentEpisode!.title}'
                      : 'Loading stream...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          // Sub / Dub Pill
          if (state.currentEpisode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryPurpleLight, width: 0.8),
              ),
              child: Text(
                state.currentEpisode!.isDub ? 'DUB' : 'SUB',
                style: const TextStyle(
                  color: AppTheme.primaryPurpleLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(width: 10),
          // Quality Selector Pill
          if (state.currentSource != null)
            GestureDetector(
              onTap: () {
                _onUserInteraction();
                if (state.streamBundle != null) {
                  QualitySelectorSheet.show(
                    context,
                    sources: state.streamBundle!.sources,
                    currentSource: state.currentSource,
                    onSourceSelected: widget.onSelectSource,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hd_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      state.currentSource!.quality,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.onDownload != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 24),
              tooltip: 'Download Episode',
              onPressed: () {
                _onUserInteraction();
                widget.onDownload?.call();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCenterControls(PlayerState state) {
    if (state.isLoadingStream) {
      return const LoadingCycle(
        size: 56,
        message: 'Injecting headers & loading stream',
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous Episode
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
          onPressed: state.hasPreviousEpisode
              ? () {
                  _onUserInteraction();
                  widget.onPlayPrevious();
                }
              : null,
          tooltip: 'Previous Episode',
        ),
        const SizedBox(width: 16),

        // Rewind 10s
        IconButton(
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
          onPressed: () {
            _onUserInteraction();
            widget.onSkipBackward10();
          },
          tooltip: 'Rewind 10s',
        ),
        const SizedBox(width: 20),

        // Play / Pause main button
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.5),
                blurRadius: 16,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 42,
            ),
            onPressed: () {
              _onUserInteraction();
              widget.onTogglePlayPause();
            },
          ),
        ),
        const SizedBox(width: 20),

        // Fast Forward 10s
        IconButton(
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 40),
          onPressed: () {
            _onUserInteraction();
            widget.onSkipForward10();
          },
          tooltip: 'Forward 10s',
        ),
        const SizedBox(width: 16),

        // Next Episode
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
          onPressed: state.hasNextEpisode
              ? () {
                  _onUserInteraction();
                  widget.onPlayNext();
                }
              : null,
          tooltip: 'Next Episode',
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, PlayerState state) {
    final currentSec = (_isDraggingSlider || _isSeeking)
        ? _sliderDragValue
        : state.position.inSeconds.toDouble();
    final totalSec = state.duration.inSeconds.toDouble();
    final maxSec = totalSec > 0 ? totalSec : 1.0;
    final clampedSec = currentSec.clamp(0.0, maxSec);
    final bufferSec = state.buffer.inSeconds.toDouble().clamp(0.0, maxSec);
    final bufferRatio = (bufferSec / maxSec).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrubbing time preview indicator
          if (_isDraggingSlider)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accentCyan, width: 1),
                ),
                child: Text(
                  _formatDuration(Duration(seconds: _sliderDragValue.toInt())),
                  style: const TextStyle(
                    color: AppTheme.accentCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          // Scrubbing slider with buffered track
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Buffered track
              Container(
                height: 4.0,
                margin: const EdgeInsets.symmetric(horizontal: 22),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: bufferRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                  activeTrackColor: AppTheme.primaryPurple,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: AppTheme.accentCyan,
                ),
                child: Slider(
                  value: clampedSec,
                  min: 0.0,
                  max: maxSec,
                  onChangeStart: (val) {
                    setState(() {
                      _isDraggingSlider = true;
                      _sliderDragValue = val;
                    });
                    _hideTimer?.cancel();
                  },
                  onChanged: (val) {
                    setState(() {
                      _sliderDragValue = val;
                    });
                  },
                  onChangeEnd: (val) {
                    final target = Duration(seconds: val.toInt());
                    setState(() {
                      _isDraggingSlider = false;
                      _sliderDragValue = val;
                      _isSeeking = true;
                    });
                    widget.onSeek(target);
                    _seekDebounceTimer?.cancel();
                    _seekDebounceTimer = Timer(const Duration(milliseconds: 600), () {
                      if (mounted) setState(() => _isSeeking = false);
                    });
                    _startHideTimer();
                  },
                ),
              ),
            ],
          ),

          // Duration timers and extra actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDuration(Duration(seconds: clampedSec.toInt()))} / ${_formatDuration(state.duration)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              Row(
                children: [
                  // Headers Indicator Tooltip
                  if (state.currentSource?.headers.isNotEmpty ?? false)
                    Tooltip(
                      message:
                          'Custom Referer & User-Agent injected into media_kit',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.greenAccent, width: 0.6),
                        ),
                        child: const Text(
                          'HEADER INJECTED',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Quality switcher button
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white, size: 22),
                    tooltip: 'Quality & Stream Settings',
                    onPressed: () {
                      _onUserInteraction();
                      if (state.streamBundle != null) {
                        QualitySelectorSheet.show(
                          context,
                          sources: state.streamBundle!.sources,
                          currentSource: state.currentSource,
                          onSourceSelected: widget.onSelectSource,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkipIntroButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black.withOpacity(0.85),
        foregroundColor: AppTheme.accentCyan,
        side: const BorderSide(color: AppTheme.accentCyan, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      icon: const Icon(Icons.fast_forward_rounded, size: 20),
      label: const Text(
        'Skip Intro (+85s)',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: () {
        _onUserInteraction();
        widget.onSkipIntro();
      },
    );
  }

  Widget _buildNotificationBanner(String message, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2438).withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.6), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF381F24).withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: widget.onRetrySource,
            child: const Text('RETRY', style: TextStyle(color: AppTheme.accentCyan)),
          ),
        ],
      ),
    );
  }
}
