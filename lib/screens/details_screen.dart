import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../models/video_source.dart';
import '../providers/anime_details_provider.dart';
import '../providers/download_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/player_provider.dart';
import '../providers/watch_history_provider.dart';
import '../services/external_player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/download_resolution_sheet.dart';
import '../widgets/loading_cycle.dart';
import 'player_screen.dart';

/// Details screen displaying anime metadata, synopsis, Sub/Dub toggle, and episode catalog
class DetailsScreen extends ConsumerStatefulWidget {
  final String animeId;

  const DetailsScreen({super.key, required this.animeId});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  bool _isSynopsisExpanded = false;
  bool _isGridView = false;
  bool _isLaunchingEpisode = false;
  String? _loadingEpisodeId;
  int _currentPage = 1;
  static const int _episodesPerPage = 30;

  void _playEpisode(
    BuildContext context, {
    required Anime anime,
    required Episode episode,
    required List<Episode> playlist,
    int? resumePosition,
  }) async {
    if (_isLaunchingEpisode) return;
    setState(() {
      _isLaunchingEpisode = true;
      _loadingEpisodeId = episode.id;
    });

    try {
      // Check if episode is downloaded locally for offline instant playback
      final downloadNotifier = ref.read(downloadProvider.notifier);
      if (downloadNotifier.isDownloaded(
        episode.id,
        animeTitle: anime.title,
        episodeNumber: episode.number,
        isDub: episode.isDub,
      )) {
        final task = downloadNotifier.getTask(
          episode.id,
          animeTitle: anime.title,
          episodeNumber: episode.number,
          isDub: episode.isDub,
        );
        if (task != null && task.filePath != null) {
          final offlineSource = VideoSource(
            url: task.filePath!,
            quality: 'Offline (${task.source.quality})',
            isHls: false,
            serverName: 'Downloaded File',
          );
          ref.read(playerProvider.notifier).setupOfflineEpisode(
                anime: anime,
                episode: episode,
                playlist: playlist,
                source: offlineSource,
                resumePositionSeconds: resumePosition,
              );

          if (context.mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PlayerScreen(),
              ),
            );
          }
          return;
        }
      }

      final ok = await ref.read(playerProvider.notifier).setupEpisode(
            anime: anime,
            episode: episode,
            playlist: playlist,
            resumePositionSeconds: resumePosition,
          );

      if (!ok) {
        if (context.mounted) {
          final errorMsg = ref.read(playerProvider).errorMessage ??
              'Episode ${episode.number} has not been uploaded yet or is currently unavailable.';
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Episode Unavailable',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
              content: Text(
                'Episode ${episode.number} cannot be played:\n\n$errorMsg\n\nThis episode may not have aired yet or has not been uploaded to streaming servers.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK', style: TextStyle(color: AppTheme.accentCyan)),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PlayerScreen(),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingEpisode = false;
          _loadingEpisodeId = null;
        });
      }
    }
  }

  void _showDownloadOptions(BuildContext context, Episode ep, Anime anime) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.offline_pin_rounded, color: Colors.greenAccent),
                title: Text('Episode ${ep.number} Downloaded'),
                subtitle: const Text('Saved locally for offline streaming.'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded, color: AppTheme.accentCyan),
                title: const Text('Open with External Player / Share'),
                subtitle: const Text('Play in VLC, MX Player, or share video file.'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  final task = ref.read(downloadProvider.notifier).getTask(
                        ep.id,
                        animeTitle: anime.title,
                        episodeNumber: ep.number,
                        isDub: ep.isDub,
                      );
                  if (task != null && task.filePath != null) {
                    ExternalPlayerService.openOrShareEpisode(
                      context: context,
                      title: '${anime.title} - Episode ${ep.number}',
                      urlOrPath: task.filePath!,
                      isLocalFile: true,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete Downloaded File', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(downloadProvider.notifier).deleteDownload(ep.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Episode ${ep.number} deleted.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar({
    required int totalPages,
    required int currentPage,
    required int totalEpisodes,
  }) {
    if (totalEpisodes <= _episodesPerPage || totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final surfaceColor = Theme.of(context).colorScheme.surfaceContainerHigh;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous Button
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              iconSize: 22,
              tooltip: 'Previous Page',
              onPressed: currentPage > 1
                  ? () => setState(() => _currentPage = currentPage - 1)
                  : null,
            ),

            // Page 1
            _buildPageNumberButton(
              page: 1,
              isSelected: currentPage == 1,
              onTap: () => setState(() => _currentPage = 1),
            ),

            // Page 2 (if available)
            if (totalPages >= 2) ...[
              const SizedBox(width: 4),
              _buildPageNumberButton(
                page: 2,
                isSelected: currentPage == 2,
                onTap: () => setState(() => _currentPage = 2),
              ),
            ],

            // Middle: Interactive Jump to Page button
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showJumpToPageDialog(totalPages, totalEpisodes),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (currentPage > 2 && currentPage < totalPages)
                      ? AppTheme.primaryPurple.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (currentPage > 2 && currentPage < totalPages)
                        ? AppTheme.primaryPurple
                        : Theme.of(context).colorScheme.outline.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (currentPage > 2 && currentPage < totalPages)
                          ? 'Page $currentPage'
                          : '...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (currentPage > 2 && currentPage < totalPages)
                            ? AppTheme.accentCyan
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_drop_down_rounded, size: 18),
                  ],
                ),
              ),
            ),

            // Last Page (if totalPages >= 3)
            if (totalPages >= 3) ...[
              const SizedBox(width: 4),
              _buildPageNumberButton(
                page: totalPages,
                isSelected: currentPage == totalPages,
                onTap: () => setState(() => _currentPage = totalPages),
              ),
            ],

            // Next Button
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              iconSize: 22,
              tooltip: 'Next Page',
              onPressed: currentPage < totalPages
                  ? () => setState(() => _currentPage = currentPage + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageNumberButton({
    required int page,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryPurple
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _showJumpToPageDialog(int totalPages, int totalEpisodes) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jump to Page (1 – $totalPages)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: totalPages,
                    itemBuilder: (context, i) {
                      final pageNum = i + 1;
                      final startEp = (pageNum - 1) * _episodesPerPage + 1;
                      final endEp = math.min(pageNum * _episodesPerPage, totalEpisodes);
                      final isSelected = pageNum == _currentPage;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppTheme.primaryPurple
                              : Theme.of(context).colorScheme.surfaceContainerHigh,
                          foregroundColor: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          child: Text(
                            '$pageNum',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          'Page $pageNum: Episodes $startEp – $endEp',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppTheme.accentCyan)
                            : null,
                        onTap: () {
                          setState(() {
                            _currentPage = pageNum;
                          });
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final animeAsync = ref.watch(animeDetailsProvider(widget.animeId));
    final episodesAsync = ref.watch(episodesProvider(widget.animeId));
    final isDub = ref.watch(isDubSelectedProvider(widget.animeId));
    final isAscending = ref.watch(episodeOrderAscendingProvider);
    final history = ref.watch(watchHistoryProvider.notifier).getHistoryForAnime(widget.animeId);

    return Scaffold(
      body: animeAsync.when(
        loading: () => const Center(
          child: LoadingCycle(message: 'Loading anime details'),
        ),
        error: (err, _) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Failed to load anime: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(animeDetailsProvider(widget.animeId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (anime) {
          return Stack(
            children: [
              CustomScrollView(
                slivers: [
              // Hero Banner & Collapsing App Bar
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                backgroundColor: AppTheme.darkBackground,
                actions: [
                  Consumer(
                    builder: (context, ref, child) {
                      final isFav = ref.watch(favoritesProvider).isAnimeFav(anime.id);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : Colors.white,
                        ),
                        tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
                        onPressed: () {
                          ref.read(favoritesProvider.notifier).toggleAnimeFavorite(anime);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFav
                                    ? 'Removed "${anime.title}" from favorites'
                                    : 'Added "${anime.title}" to favorites',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner image
                      Image.network(
                        anime.bannerImage ?? anime.coverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.darkSurfaceVariant,
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black45,
                              AppTheme.darkBackground.withOpacity(0.5),
                              AppTheme.darkBackground,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                      // Floating Anime Poster & Title details
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Poster Card
                            Container(
                              width: 100,
                              height: 145,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  anime.coverImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppTheme.darkSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Title & Quick Specs
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    anime.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (anime.japaneseTitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      anime.japaneseTitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (anime.rating != null) ...[
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          anime.rating!.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Text(
                                        anime.status,
                                        style: const TextStyle(
                                          color: AppTheme.accentCyan,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '• ${anime.type}',
                                        style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons & Synopsis
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Resume / Start Watching primary CTA button
                      episodesAsync.when(
                        data: (episodes) {
                          if (episodes.isEmpty) return const SizedBox.shrink();
                          final resumeEp = history != null
                              ? episodes.firstWhere(
                                  (e) => e.number == history.episode.number,
                                  orElse: () => episodes.first,
                                )
                              : episodes.first;

                          final isCtaLoading = _isLaunchingEpisode && _loadingEpisodeId == resumeEp.id;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: isCtaLoading
                                    ? const LoadingCycle(size: 20, strokeWidth: 2.2, showCore: false)
                                    : const Icon(Icons.play_arrow_rounded, size: 28),
                                label: Text(
                                  isCtaLoading
                                      ? 'Loading Stream...'
                                      : (history != null
                                          ? 'Resume Episode ${resumeEp.number}\n(${history.formattedProgress.split(' / ').first})'
                                          : 'Watch Episode 1'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: isCtaLoading
                                    ? null
                                    : () {
                                        _playEpisode(
                                          context,
                                          anime: anime,
                                          episode: resumeEp,
                                          playlist: episodes,
                                          resumePosition: history?.positionSeconds,
                                        );
                                      },
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      // Genres Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: anime.genres.map((g) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.darkSurfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              g,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Synopsis with expand/collapse
                      GestureDetector(
                        onTap: () => setState(() => _isSynopsisExpanded = !_isSynopsisExpanded),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.synopsis,
                              maxLines: _isSynopsisExpanded ? null : 3,
                              overflow: _isSynopsisExpanded ? null : TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isSynopsisExpanded ? 'Show less' : 'Read more',
                              style: const TextStyle(
                                color: AppTheme.accentCyan,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 10),

                      // Sub / Dub Toggle & Controls Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Episodes',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (episodesAsync.valueOrNull != null &&
                                  episodesAsync.valueOrNull!.length > _episodesPerPage)
                                Text(
                                  'Showing ${((_currentPage - 1) * _episodesPerPage + 1).clamp(1, episodesAsync.valueOrNull!.length)}–${math.min(_currentPage * _episodesPerPage, episodesAsync.valueOrNull!.length)} of ${episodesAsync.valueOrNull!.length}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),

                          Row(
                            children: [
                              // Sub / Dub Segmented Button
                              SegmentedButton<bool>(
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: WidgetStateProperty.resolveWith(
                                    (states) => states.contains(WidgetState.selected)
                                        ? AppTheme.primaryPurple
                                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                                  ),
                                ),
                                segments: const [
                                  ButtonSegment<bool>(
                                    value: false,
                                    label: Text('SUB', style: TextStyle(fontSize: 11)),
                                  ),
                                  ButtonSegment<bool>(
                                    value: true,
                                    label: Text('DUB', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                                selected: {isDub},
                                onSelectionChanged: (newSelection) {
                                  setState(() => _currentPage = 1);
                                  ref
                                      .read(isDubSelectedProvider(widget.animeId).notifier)
                                      .state = newSelection.first;
                                },
                              ),
                              const SizedBox(width: 8),

                              // Sort Asc / Desc
                              IconButton(
                                icon: Icon(
                                  isAscending
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                tooltip: isAscending ? 'Sort 1 -> N' : 'Sort N -> 1',
                                onPressed: () {
                                  ref.read(episodeOrderAscendingProvider.notifier).state =
                                      !isAscending;
                                },
                              ),

                              // Grid / List toggle
                              IconButton(
                                icon: Icon(
                                  _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                tooltip: _isGridView ? 'List View' : 'Grid View',
                                onPressed: () => setState(() => _isGridView = !_isGridView),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Episode List / Grid Content
              episodesAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(
                      child: LoadingCycle(message: 'Loading episodes'),
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Failed to load episodes: $err'),
                    ),
                  ),
                ),
                data: (rawEpisodes) {
                  if (rawEpisodes.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No episodes found for this selection.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    );
                  }

                  final episodes = isAscending
                      ? rawEpisodes
                      : rawEpisodes.reversed.toList();

                  final totalEpisodes = episodes.length;
                  final totalPages = (totalEpisodes / _episodesPerPage).ceil();
                  final safePage = _currentPage.clamp(1, math.max(1, totalPages)).toInt();
                  final startIndex = (safePage - 1) * _episodesPerPage;
                  final endIndex = math.min(startIndex + _episodesPerPage, totalEpisodes).toInt();
                  final pagedEpisodes = episodes.sublist(startIndex, endIndex);

                  Widget buildGridView() {
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 65,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final ep = pagedEpisodes[index];
                            final isWatched = history != null &&
                                history.episode.number == ep.number &&
                                history.isCompleted;
                            final isDl = ref.watch(downloadProvider.notifier).isDownloaded(
                                  ep.id,
                                  animeTitle: anime.title,
                                  episodeNumber: ep.number,
                                  isDub: ep.isDub,
                                );
                            final isDling = ref.watch(downloadProvider.notifier).isDownloading(ep.id);
                            final isEpFav = ref.watch(favoritesProvider).isEpisodeFav(ep.id);
                            final isLoading = _loadingEpisodeId == ep.id;

                            return InkWell(
                              mouseCursor: SystemMouseCursors.click,
                              hoverColor: AppTheme.primaryPurple.withOpacity(0.25),
                              onTap: () {
                                _playEpisode(
                                  context,
                                  anime: anime,
                                  episode: ep,
                                  playlist: episodes,
                                );
                              },
                              onLongPress: () {
                                ref.read(favoritesProvider.notifier).toggleEpisodeFavorite(anime, ep);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEpFav
                                          ? 'Removed Episode ${ep.number} from favorites'
                                          : 'Favorited Episode ${ep.number}',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isWatched
                                      ? AppTheme.primaryPurple.withOpacity(0.3)
                                      : Theme.of(context).colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDl
                                        ? Colors.greenAccent
                                        : isWatched
                                            ? AppTheme.accentCyan
                                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isLoading)
                                      const LoadingCycle(
                                        size: 20,
                                        strokeWidth: 2.2,
                                        showCore: false,
                                      )
                                    else if (isDling)
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.greenAccent,
                                        ),
                                      )
                                    else
                                      Text(
                                        '${ep.number}',
                                        style: TextStyle(
                                          color: isDl
                                              ? Colors.greenAccent
                                              : isWatched
                                                  ? AppTheme.accentCyan
                                                  : Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    if (isDl)
                                      const Positioned(
                                        top: 3,
                                        right: 3,
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 10,
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                    if (isEpFav)
                                      const Positioned(
                                        top: 3,
                                        left: 3,
                                        child: Icon(
                                          Icons.favorite_rounded,
                                          size: 10,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: pagedEpisodes.length,
                        ),
                      ),
                    );
                  }

                  Widget buildListView() {
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final ep = pagedEpisodes[index];
                            final isCurrentlyWatched = history != null &&
                                history.episode.number == ep.number;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: Theme.of(context).colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isCurrentlyWatched
                                        ? AppTheme.primaryPurpleLight.withOpacity(0.5)
                                        : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  mouseCursor: SystemMouseCursors.click,
                                  hoverColor: AppTheme.primaryPurple.withOpacity(0.08),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${ep.number}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    ep.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            ep.isDub ? 'English Dub' : 'Japanese Sub',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          if (ep.isFiller) ...[
                                            const SizedBox(width: 8),
                                            const Text(
                                              '• Filler',
                                              style: TextStyle(
                                                color: Colors.orangeAccent,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (isCurrentlyWatched) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          'Resume (${history.formattedProgress.split(' / ').first})',
                                          style: const TextStyle(
                                            color: AppTheme.accentCyan,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Favorite Episode Button
                                      Consumer(
                                        builder: (context, ref, child) {
                                          final isEpFav = ref.watch(favoritesProvider).isEpisodeFav(ep.id);
                                          return IconButton(
                                            icon: Icon(
                                              isEpFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                              color: isEpFav ? Colors.redAccent : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                              size: 20,
                                            ),
                                            tooltip: isEpFav ? 'Unfavorite Episode' : 'Favorite Episode',
                                            onPressed: () {
                                              ref.read(favoritesProvider.notifier).toggleEpisodeFavorite(anime, ep);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    isEpFav
                                                        ? 'Removed Episode ${ep.number} from favorites'
                                                        : 'Favorited Episode ${ep.number}',
                                                  ),
                                                  duration: const Duration(seconds: 1),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),

                                      // Download Button & Status
                                      Builder(
                                        builder: (context) {
                                          final isDl = ref.watch(downloadProvider.notifier).isDownloaded(
                                  ep.id,
                                  animeTitle: anime.title,
                                  episodeNumber: ep.number,
                                  isDub: ep.isDub,
                                );
                                          final isDling = ref.watch(downloadProvider.notifier).isDownloading(ep.id);
                                          final dlTask = ref.watch(downloadProvider)[ep.id];

                                          if (isDling && dlTask != null) {
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    CircularProgressIndicator(
                                                      value: dlTask.progress > 0 ? dlTask.progress : null,
                                                      strokeWidth: 2.5,
                                                      color: AppTheme.accentCyan,
                                                    ),
                                                    Text(
                                                      '${(dlTask.progress * 100).toInt()}%',
                                                      style: const TextStyle(fontSize: 8, color: Colors.white70),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }

                                          if (isDl) {
                                            return IconButton(
                                              icon: const Icon(
                                                Icons.check_circle_rounded,
                                                color: Colors.greenAccent,
                                                size: 24,
                                              ),
                                              tooltip: 'Downloaded (Offline Ready)',
                                              onPressed: () {
                                                _showDownloadOptions(context, ep, anime);
                                              },
                                            );
                                          }

                                          return IconButton(
                                            icon: Icon(
                                              Icons.download_for_offline_outlined,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              size: 22,
                                            ),
                                            tooltip: 'Download Episode',
                                            onPressed: () {
                                              DownloadResolutionSheet.show(
                                                context,
                                                anime: anime,
                                                episode: ep,
                                                onQualitySelected: (chosenSource, subUrl) {
                                                  ref.read(downloadProvider.notifier).startDownload(
                                                        anime: anime,
                                                        episode: ep,
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
                                                            child: Text(
                                                              'Downloading Episode ${ep.number} (${chosenSource.quality}) with subtitles...',
                                                              style: const TextStyle(color: Colors.white),
                                                            ),
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
                                            },
                                          );
                                        },
                                      ),

                                      // Play button or loading spinner
                                      if (_loadingEpisodeId == ep.id)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6),
                                          child: LoadingCycle(
                                            size: 24,
                                            strokeWidth: 2.5,
                                            showCore: false,
                                          ),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(
                                            Icons.play_circle_fill_rounded,
                                            color: AppTheme.primaryPurple,
                                            size: 32,
                                          ),
                                          onPressed: () {
                                            _playEpisode(
                                              context,
                                              anime: anime,
                                              episode: ep,
                                              playlist: episodes,
                                              resumePosition: isCurrentlyWatched
                                                  ? history.positionSeconds
                                                  : null,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    _playEpisode(
                                      context,
                                      anime: anime,
                                      episode: ep,
                                      playlist: episodes,
                                      resumePosition: isCurrentlyWatched
                                          ? history.positionSeconds
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          childCount: pagedEpisodes.length,
                        ),
                      ),
                    );
                  }

                  return SliverMainAxisGroup(
                    slivers: [
                      if (totalEpisodes > _episodesPerPage)
                        SliverToBoxAdapter(
                          child: _buildPaginationBar(
                            totalPages: totalPages,
                            currentPage: safePage,
                            totalEpisodes: totalEpisodes,
                          ),
                        ),
                      if (_isGridView)
                        buildGridView()
                      else
                        buildListView(),
                      if (totalEpisodes > _episodesPerPage)
                        SliverToBoxAdapter(
                          child: _buildPaginationBar(
                            totalPages: totalPages,
                            currentPage: safePage,
                            totalEpisodes: totalEpisodes,
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
          if (_isLaunchingEpisode)
            const LoadingCycleOverlay(
              title: 'Loading Episode',
              subtitle: 'Resolving stream sources & preparing playback...',
            ),
        ],
      );
    },
      ),
    );
  }
}
