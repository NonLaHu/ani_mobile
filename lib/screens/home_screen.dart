import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../providers/player_provider.dart';
import '../providers/scraper_provider.dart';
import '../providers/search_provider.dart';
import '../providers/watch_history_provider.dart';
import '../services/scraper/scraper_factory.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card.dart';
import '../widgets/history_card.dart';
import 'details_screen.dart';
import 'player_screen.dart';

/// Home screen featuring search, continue watching queue, and anime catalog grid
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final activeQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final historyList = ref.watch(watchHistoryProvider);
    final currentScraperType = ref.watch(scraperTypeProvider);

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
              text: const TextSpan(
                text: 'ani-',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'mobile',
                    style: TextStyle(
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Engine Switcher (Demo vs Live)
          PopupMenuButton<ScraperType>(
            tooltip: 'Switch Scraper Engine',
            initialValue: currentScraperType,
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentScraperType == ScraperType.demo
                      ? AppTheme.accentCyan
                      : AppTheme.primaryPurple,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    currentScraperType == ScraperType.demo
                        ? Icons.science_outlined
                        : Icons.wifi_tethering_rounded,
                    size: 14,
                    color: currentScraperType == ScraperType.demo
                        ? AppTheme.accentCyan
                        : AppTheme.primaryPurpleLight,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    currentScraperType == ScraperType.demo ? 'DEMO' : 'LIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: currentScraperType == ScraperType.demo
                          ? AppTheme.accentCyan
                          : AppTheme.primaryPurpleLight,
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
                    type == ScraperType.demo
                        ? 'Switched to Demo Engine (Guaranteed working streams)'
                        : 'Switched to Live Provider (ani-mobile architecture)',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ScraperType.demo,
                child: Text('Demo Scraper (High Stability)'),
              ),
              const PopupMenuItem(
                value: ScraperType.live,
                child: Text('Live Provider (Gogo/AllAnime)'),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(searchResultsProvider);
          ref.invalidate(trendingAnimeProvider);
        },
        color: AppTheme.primaryPurple,
        backgroundColor: AppTheme.darkSurface,
        child: CustomScrollView(
          slivers: [
            // Search Bar Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _onSearchSubmitted,
                  decoration: InputDecoration(
                    hintText: 'Search anime (e.g. Jujutsu, Frieren, Titan)...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.textMuted,
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

            // Continue Watching Section (only shown when not actively searching)
            if (activeQuery.isEmpty && historyList.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Continue Watching',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(watchHistoryProvider.notifier).clearAll();
                        },
                        child: const Text(
                          'Clear All',
                          style: TextStyle(
                            color: AppTheme.textMuted,
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
                        onTap: () async {
                          // Quick resume to player
                          await ref.read(playerProvider.notifier).setupEpisode(
                                anime: item.anime,
                                episode: item.episode,
                                playlist: [item.episode],
                                resumePositionSeconds: item.positionSeconds,
                              );
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PlayerScreen(),
                              ),
                            );
                          }
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

            // Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Icon(
                      activeQuery.isNotEmpty
                          ? Icons.search_rounded
                          : Icons.local_fire_department_rounded,
                      color: activeQuery.isNotEmpty
                          ? AppTheme.accentCyan
                          : AppTheme.accentCoral,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activeQuery.isNotEmpty
                          ? 'Search Results for "$activeQuery"'
                          : 'Trending & Popular Anime',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
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
                          style: const TextStyle(color: AppTheme.textSecondary),
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
                          const Icon(
                            Icons.search_off_rounded,
                            size: 56,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            activeQuery.isNotEmpty
                                ? 'No anime found matching "$activeQuery"'
                                : 'No titles available currently',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try searching for "Jujutsu", "Frieren", or "Solo"',
                            style: TextStyle(
                              color: AppTheme.textMuted,
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

            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
}
