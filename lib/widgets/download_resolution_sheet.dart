import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../models/video_source.dart';
import '../providers/scraper_provider.dart';
import '../theme/app_theme.dart';
import 'loading_cycle.dart';

/// Modal bottom sheet allowing users to choose the video resolution and quality
/// when downloading an anime episode, ensuring subtitles are downloaded alongside the video.
class DownloadResolutionSheet extends ConsumerStatefulWidget {
  final Anime anime;
  final Episode episode;
  final StreamBundle? preloadedBundle;
  final void Function(VideoSource source, String? subtitleUrl) onQualitySelected;

  const DownloadResolutionSheet({
    super.key,
    required this.anime,
    required this.episode,
    this.preloadedBundle,
    required this.onQualitySelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Anime anime,
    required Episode episode,
    StreamBundle? preloadedBundle,
    required void Function(VideoSource source, String? subtitleUrl) onQualitySelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DownloadResolutionSheet(
        anime: anime,
        episode: episode,
        preloadedBundle: preloadedBundle,
        onQualitySelected: onQualitySelected,
      ),
    );
  }

  @override
  ConsumerState<DownloadResolutionSheet> createState() => _DownloadResolutionSheetState();
}

class _DownloadResolutionSheetState extends ConsumerState<DownloadResolutionSheet> {
  StreamBundle? _bundle;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedBundle != null) {
      _bundle = widget.preloadedBundle;
    } else {
      _fetchSources();
    }
  }

  Future<void> _fetchSources() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final scraper = ref.read(scraperServiceProvider);
      final bundle = await scraper.getStreamSources(
        widget.episode.id,
        dub: widget.episode.isDub,
      );

      if (mounted) {
        setState(() {
          _bundle = bundle;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  IconData _getQualityIcon(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('1080') || q.contains('fhd')) return Icons.hd_rounded;
    if (q.contains('720') || q.contains('hd')) return Icons.high_quality_rounded;
    if (q.contains('480') || q.contains('sd')) return Icons.sd_rounded;
    if (q.contains('360')) return Icons.low_priority_rounded;
    return Icons.auto_mode_rounded;
  }

  Color _getQualityColor(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('1080')) return const Color(0xFF00E5FF);
    if (q.contains('720')) return const Color(0xFF7C4DFF);
    if (q.contains('480')) return Colors.orangeAccent;
    if (q.contains('360')) return Colors.tealAccent;
    return AppTheme.primaryPurpleLight;
  }

  @override
  Widget build(BuildContext context) {
    final subtitleUrl = _bundle?.subtitles.isNotEmpty == true
        ? (_bundle!.subtitles.firstWhere(
            (s) => s.label.toLowerCase().contains('eng'),
            orElse: () => _bundle!.subtitles.first,
          )).url
        : null;

    final hasSubtitles = subtitleUrl != null && subtitleUrl.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    color: AppTheme.accentCyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download Episode ${widget.episode.number}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.anime.title} • ${widget.episode.isDub ? "English Dub" : "Japanese Sub"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Subtitle info pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasSubtitles
                    ? Colors.greenAccent.withOpacity(0.1)
                    : Colors.amberAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasSubtitles
                      ? Colors.greenAccent.withOpacity(0.3)
                      : Colors.amberAccent.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasSubtitles ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
                    size: 16,
                    color: hasSubtitles ? Colors.greenAccent : Colors.amberAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasSubtitles
                          ? 'Subtitles (.vtt) will be saved alongside the video with identical name'
                          : (widget.episode.isDub
                              ? 'English audio track included with video'
                              : 'Resolving subtitle streams...'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: hasSubtitles ? Colors.greenAccent : Colors.amberAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF262B3D)),
            const SizedBox(height: 8),

            const Text(
              'Select Download Resolution',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Body: Loading, Error, or Sources List
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: LoadingCycle(
                    size: 42,
                    strokeWidth: 3,
                    message: 'Fetching available resolutions',
                  ),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.amberAccent, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                        onPressed: _fetchSources,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry Fetching Qualities'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_bundle != null && _bundle!.sources.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bundle!.sources.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final source = _bundle!.sources[index];
                  final qualityColor = _getQualityColor(source.quality);
                  final qualityIcon = _getQualityIcon(source.quality);
                  final isRecommended = source.quality.contains('1080') || (index == 0 && !_bundle!.sources.any((s) => s.quality.contains('1080')));

                  return Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onQualitySelected(source, subtitleUrl);
                      },
                      hoverColor: AppTheme.primaryPurple.withOpacity(0.18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: qualityColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: qualityColor.withOpacity(0.35)),
                              ),
                              child: Icon(qualityIcon, color: qualityColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        source.quality,
                                        style: TextStyle(
                                          color: qualityColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isRecommended) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentCyan.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.accentCyan, width: 0.8),
                                          ),
                                          child: const Text(
                                            'BEST',
                                            style: TextStyle(
                                              color: AppTheme.accentCyan,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    source.serverName,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Colors.white38,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No downloadable streams found for this episode.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
