import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../providers/anime_details_provider.dart';
import '../providers/player_provider.dart';
import '../providers/watch_history_provider.dart';
import '../theme/app_theme.dart';
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

  void _playEpisode(
    BuildContext context, {
    required Anime anime,
    required Episode episode,
    required List<Episode> playlist,
    int? resumePosition,
  }) async {
    await ref.read(playerProvider.notifier).setupEpisode(
          anime: anime,
          episode: episode,
          playlist: playlist,
          resumePositionSeconds: resumePosition,
        );

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PlayerScreen(),
        ),
      );
    }
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
          child: CircularProgressIndicator(color: AppTheme.primaryPurple),
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
          return CustomScrollView(
            slivers: [
              // Hero Banner & Collapsing App Bar
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                backgroundColor: AppTheme.darkBackground,
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
                                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                                label: Text(
                                  history != null
                                      ? 'Resume Episode ${resumeEp.number} (${history.formattedProgress.split(' / ').first})'
                                      : 'Watch Episode 1',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
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
                          const Text(
                            'Episodes',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                                        : AppTheme.darkSurfaceVariant,
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
                                  color: AppTheme.textSecondary,
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
                                  color: AppTheme.textSecondary,
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
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryPurple),
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

                  if (_isGridView) {
                    // Grid View: compact episode buttons
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
                            final ep = episodes[index];
                            final isWatched = history != null &&
                                history.episode.number == ep.number &&
                                history.isCompleted;

                            return InkWell(
                              onTap: () {
                                _playEpisode(
                                  context,
                                  anime: anime,
                                  episode: ep,
                                  playlist: episodes,
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isWatched
                                      ? AppTheme.primaryPurple.withOpacity(0.3)
                                      : AppTheme.darkSurfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isWatched
                                        ? AppTheme.accentCyan
                                        : const Color(0xFF2C3247),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${ep.number}',
                                    style: TextStyle(
                                      color: isWatched
                                          ? AppTheme.accentCyan
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: episodes.length,
                        ),
                      ),
                    );
                  }

                  // List View: Rich episode cards
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ep = episodes[index];
                          final isCurrentlyWatched = history != null &&
                              history.episode.number == ep.number;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.darkSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrentlyWatched
                                    ? AppTheme.primaryPurpleLight.withOpacity(0.5)
                                    : const Color(0xFF222638),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.darkSurfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${ep.number}',
                                    style: const TextStyle(
                                      color: Colors.white,
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
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    ep.isDub ? 'English Dub' : 'Japanese Sub',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
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
                                  if (isCurrentlyWatched) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '• Resume ${history.formattedProgress.split(' / ').first}',
                                      style: const TextStyle(
                                        color: AppTheme.accentCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: IconButton(
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
                          );
                        },
                        childCount: episodes.length,
                      ),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}
