import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime.dart';
import 'scraper_provider.dart';

const String _recentQueriesKey = 'ani_mobile_recent_searches_v1';

/// Holds the active search query in the search bar
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Fetches trending anime titles for discovery
final trendingAnimeProvider = FutureProvider<List<Anime>>((ref) async {
  final scraper = ref.watch(scraperServiceProvider);
  return scraper.getTrendingAnime();
});

/// Fetches search results based on active query, falling back to trending if query is empty
final searchResultsProvider = FutureProvider<List<Anime>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final scraper = ref.watch(scraperServiceProvider);

  if (query.isEmpty) {
    return ref.watch(trendingAnimeProvider.future);
  }

  return scraper.searchAnime(query);
});

/// StateNotifier to manage recent text searches
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentQueriesKey);
      if (list != null) state = list;
    } catch (_) {}
  }

  Future<void> addQuery(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    final updated = List<String>.from(state)..remove(query);
    updated.insert(0, query);
    if (updated.length > 10) updated.removeLast();
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentQueriesKey, updated);
  }

  Future<void> clearHistory() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentQueriesKey);
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});
