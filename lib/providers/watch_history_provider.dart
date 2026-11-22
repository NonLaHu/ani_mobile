import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../models/watch_history.dart';

const String _historyPrefKey = 'ani_mobile_watch_history_v1';

/// Manages and persists anime watch history using SharedPreferences
class WatchHistoryNotifier extends StateNotifier<List<WatchHistoryItem>> {
  WatchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_historyPrefKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as List<dynamic>;
        final items = decoded
            .map((item) => WatchHistoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
        // Sort newest first
        items.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
        state = items;
      }
    } catch (e) {
      print('Failed to load watch history: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(state.map((item) => item.toJson()).toList());
      await prefs.setString(_historyPrefKey, encoded);
    } catch (e) {
      print('Failed to persist watch history: $e');
    }
  }

  /// Updates or inserts an anime watch progress entry
  Future<void> saveProgress({
    required Anime anime,
    required Episode episode,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    if (positionSeconds < 2) return; // Ignore accidental clicks

    final existingIndex = state.indexWhere(
      (item) => item.anime.id == anime.id,
    );

    final newItem = WatchHistoryItem(
      anime: anime,
      episode: episode,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      lastWatchedAt: DateTime.now(),
    );

    final updated = List<WatchHistoryItem>.from(state);
    if (existingIndex >= 0) {
      updated.removeAt(existingIndex);
    }
    updated.insert(0, newItem); // Put most recent at top

    // Keep history bounded to 50 entries
    if (updated.length > 50) {
      updated.removeRange(50, updated.length);
    }

    state = updated;
    await _persist();
  }

  /// Finds the last watched episode and progress for an anime, if any
  WatchHistoryItem? getHistoryForAnime(String animeId) {
    try {
      return state.firstWhere((item) => item.anime.id == animeId);
    } catch (_) {
      return null;
    }
  }

  /// Deletes a specific history record
  Future<void> removeItem(String animeId) async {
    state = state.where((item) => item.anime.id != animeId).toList();
    await _persist();
  }

  /// Clears all watch history
  Future<void> clearAll() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyPrefKey);
  }
}

final watchHistoryProvider =
    StateNotifierProvider<WatchHistoryNotifier, List<WatchHistoryItem>>((ref) {
  return WatchHistoryNotifier();
});
