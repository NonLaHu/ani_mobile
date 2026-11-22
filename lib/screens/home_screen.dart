import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../models/video_source.dart';
import '../providers/download_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/player_provider.dart';
import '../providers/scraper_provider.dart';
import '../providers/search_provider.dart';
import '../providers/watch_history_provider.dart';
import '../services/scraper/scraper_factory.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import '../widgets/history_card.dart';
import 'details_screen.dart';
import 'downloads_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

/// Home screen featuring search, continue watching queue, favorites, and anime catalog grid
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0: Discover, 1: Favorites
  bool _isOpeningPlayer = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
    if (query.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).addQuery(query);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  Future<void> _safeOpenPlayer(Future<bool> Function() setup) async {
    if (_isOpeningPlayer) return;
    setState(() => _isOpeningPlayer = true);
    try {
      final success = await setup();
      if (!success) {
        if (mounted) {
          final err = ref.read(playerProvider).errorMessage ?? 'Episode stream is currently unavailable.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(err)),
                ],
              ),
              backgroundColor: const Color(0xFF2C243B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PlayerScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load video stream: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningPlayer = false);
      } else {
        _isOpeningPlayer = false;
      }
    }
  }

  void _playFavoriteEpisode(BuildContext context, String animeId, String animeTitle, Episode episode) {
    _safeOpenPlayer(() async {
      // Check if downloaded
      final downloadNotifier = ref.read(downloadProvider.notifier);
      final anime = Anime(
        id: animeId,
        title: animeTitle,
        coverImage: '',
        synopsis: 'Favorite Episode',
      );

      if (downloadNotifier.isDownloaded(episode.id)) {
        final task = downloadNotifier.getTask(episode.id);
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
                playlist: [episode],
                source: offlineSource,
              );
          return true;
        }
      }

      return await ref.read(playerProvider.notifier).setupEpisode(
            anime: anime,
            episode: episode,
            playlist: [episode],
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final historyList = ref.watch(watchHistoryProvider);
    final currentScraperType = ref.watch(scraperTypeProvider);
    final downloadState = ref.watch(downloadProvider);
    final favoritesState = ref.watch(favoritesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalFavoritesCount = favoritesState.animes.length + favoritesState.episodes.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.terminal_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(
                text: 'ani-',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'mobile',
                    style: TextStyle(
                      color: isDark ? AppTheme.accentCyan : AppTheme.primaryPurpleLight,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Engine Switcher (HiAnime vs Live vs Demo)
          PopupMenuButton<ScraperType>(
            tooltip: 'Switch Scraper Engine',
            initialValue: currentScraperType,
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentScraperType == ScraperType.hianime
                      ? (isDark ? AppTheme.accentCyan : AppTheme.primaryPurple)
                      : currentScraperType == ScraperType.live
                          ? AppTheme.primaryPurpleLight
                          : Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    currentScraperType == ScraperType.hianime
                        ? Icons.bolt_rounded
                        : currentScraperType == ScraperType.live
                            ? Icons.wifi_tethering_rounded
                            : Icons.science_outlined,
                    size: 14,
                    color: currentScraperType == ScraperType.hianime
                        ? (isDark ? AppTheme.accentCyan : AppTheme.primaryPurple)
                        : currentScraperType == ScraperType.live
                            ? AppTheme.primaryPurpleLight
                            : Colors.grey,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    currentScraperType == ScraperType.hianime
                        ? 'ANI-CLI'
                        : currentScraperType == ScraperType.live
                            ? 'LIVE'
                            : 'DEMO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: currentScraperType == ScraperType.hianime
                          ? (isDark ? AppTheme.accentCyan : AppTheme.primaryPurple)
                          : currentScraperType == ScraperType.live
                              ? AppTheme.primaryPurpleLight
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            onSelected: (type) {
              ref.read(scraperTypeProvider.notifier).state = type;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    type == ScraperType.hianime
                        ? 'Switched to ani-mobile Engine (HiAnime / ZokoAnime)'
                        : type == ScraperType.live
                            ? 'Switched to Live Provider (Gogo/AllAnime)'
                            : 'Switched to Demo Engine (Guaranteed test streams)',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ScraperType.hianime,
                child: Text('ani-mobile Engine (HiAnime / ZokoAnime)'),
              ),
              const PopupMenuItem(
                value: ScraperType.live,
                child: Text('Live Provider (Gogo/AllAnime)'),
              ),
              const PopupMenuItem(
                value: ScraperType.demo,
                child: Text('Demo Scraper (Offline Test Streams)'),
              ),
            ],
          ),
          const SizedBox(width: 4),

          // Downloads Page Button with live count badge
          IconButton(
            icon: Badge(
              isLabelVisible: downloadState.activeDownloadCount > 0,
              label: Text('${downloadState.activeDownloadCount}'),
              child: Icon(
                Icons.download_rounded,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            tooltip: 'Downloaded Videos',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DownloadsScreen(),
                ),
              );
            },
          ),

          // Settings Page Button
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
        bottom: _isOpeningPlayer
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: AppTheme.accentCyan,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(searchResultsProvider);
          ref.invalidate(trendingAnimeProvider);
        },
        color: AppTheme.primaryPurple,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: CustomScrollView(
          slivers: [
            // Search Bar Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _onSearchSubmitted,
                  decoration: InputDecoration(
                    hintText: 'Search anime (e.g. Jujutsu, Frieren, Titan)...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                    ),
                    suffixIcon: activeQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: _clearSearch,
                          )
                        : null,
                  ),
                ),
              ),
            ),

            // Navigation Tabs (Discover vs Favorites)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.explore_rounded, size: 18),
                      label: Text('Discover'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(
                        totalFavoritesCount > 0 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 18,
                        color: totalFavoritesCount > 0 ? Colors.redAccent : null,
                      ),
                      label: Text(
                        totalFavoritesCount > 0 ? 'Favorites ($totalFavoritesCount)' : 'Favorites',
                      ),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _selectedTab = selected.first;
                    });
                  },
                ),
              ),
            ),

            // TAB 0: DISCOVER (Continue Watching + Anime Catalog)
            if (_selectedTab == 0) ...[
              // Continue Watching Section
              if (activeQuery.isEmpty && historyList.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Continue Watching',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(watchHistoryProvider.notifier).clearAll();
                          },
                          child: Text(
                            'Clear All',
                            style: TextStyle(
                              color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 185,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: historyList.length,
                      itemBuilder: (context, index) {
                        final item = historyList[index];
                        return HistoryCard(
                          item: item,
                          onTap: () {
                            _safeOpenPlayer(() async {
                              return await ref.read(playerProvider.notifier).setupEpisode(
                                    anime: item.anime,
                                    episode: item.episode,
                                    playlist: [item.episode],
                                    resumePositionSeconds: item.positionSeconds,
                                  );
                            });
                          },
                          onDelete: () {
                            ref
                                .read(watchHistoryProvider.notifier)
                                .removeItem(item.anime.id);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Catalog Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        activeQuery.isNotEmpty
                            ? Icons.search_rounded
                            : Icons.local_fire_department_rounded,
                        color: activeQuery.isNotEmpty
                            ? (isDark ? AppTheme.accentCyan : AppTheme.primaryPurple)
                            : AppTheme.accentCoral,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activeQuery.isNotEmpty
                            ? 'Search Results for "$activeQuery"'
                            : 'Trending & Popular Anime',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Anime Grid / Results
              searchResultsAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
                error: (error, stack) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load anime: $error',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ref.invalidate(searchResultsProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (animeList) {
                  if (animeList.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 56,
                              color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              activeQuery.isNotEmpty
                                  ? 'No anime found matching "$activeQuery"'
                                  : 'No titles available currently',
                              style: TextStyle(
                                color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try searching for "Jujutsu", "Frieren", or "Solo"',
                              style: TextStyle(
                                color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.58,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final anime = animeList[index];
                          return AnimeCard(
                            anime: anime,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DetailsScreen(animeId: anime.id),
                                ),
                              );
                            },
                          );
                        },
                        childCount: animeList.length,
                      ),
                    ),
                  );
                },
              ),
            ]

            // TAB 1: FAVORITES (Anime + Favorite Episodes)
            else ...[
              if (totalFavoritesCount == 0)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 68,
                            color: isDark
                                ? AppTheme.textMuted.withOpacity(0.4)
                                : AppTheme.lightTextMuted.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Favorites Added Yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the heart icon on any anime poster or episode to save it here for fast access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Favorite Anime Section
                if (favoritesState.animes.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Favorite Anime (${favoritesState.animes.length})',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.58,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final fav = favoritesState.animes[index];
                          return AnimeCard(
                            anime: fav.anime,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DetailsScreen(animeId: fav.anime.id),
                                ),
                              );
                            },
                          );
                        },
                        childCount: favoritesState.animes.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 36)),
                ],

                // Favorite Episodes Section
                if (favoritesState.episodes.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.video_library_rounded, color: AppTheme.accentCyan, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Favorite Episodes (${favoritesState.episodes.length})',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final favEp = favoritesState.episodes[index];
                        final ep = favEp.episode;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              mouseCursor: SystemMouseCursors.click,
                              hoverColor: AppTheme.primaryPurple.withOpacity(0.08),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                favEp.animeTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              subtitle: Text(
                                'Episode ${ep.number}: ${ep.title} • ${ep.isDub ? "DUB" : "SUB"}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: AppTheme.primaryPurple,
                                      size: 32,
                                    ),
                                    tooltip: 'Play Episode',
                                    onPressed: () {
                                      _playFavoriteEpisode(context, favEp.animeId, favEp.animeTitle, ep);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.redAccent,
                                      size: 22,
                                    ),
                                    tooltip: 'Remove Favorite',
                                    onPressed: () {
                                      final fakeAnime = Anime(
                                        id: favEp.animeId,
                                        title: favEp.animeTitle,
                                        coverImage: '',
                                        synopsis: '',
                                      );
                                      ref.read(favoritesProvider.notifier).toggleEpisodeFavorite(fakeAnime, ep);
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                _playFavoriteEpisode(context, favEp.animeId, favEp.animeTitle, ep);
                              },
                            ),
                          ),
                        );
                      },
                      childCount: favoritesState.episodes.length,
                    ),
                  ),
                ],
              ],
            ],

            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
}
