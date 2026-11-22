import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../models/favorite_item.dart';

class FavoritesState {
  final List<FavoriteAnime> animes;
  final List<FavoriteEpisode> episodes;

  const FavoritesState({
    this.animes = const [],
    this.episodes = const [],
  });

  bool isAnimeFav(String animeId) => animes.any((f) => f.anime.id == animeId);
  bool isEpisodeFav(String episodeId) => episodes.any((f) => f.episode.id == episodeId);

  FavoritesState copyWith({
    List<FavoriteAnime>? animes,
    List<FavoriteEpisode>? episodes,
  }) {
    return FavoritesState(
      animes: animes ?? this.animes,
      episodes: episodes ?? this.episodes,
    );
  }
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  static const String _animeKey = 'ani_mobile_favorite_animes_v1';
  static const String _episodeKey = 'ani_mobile_favorite_episodes_v1';

  FavoritesNotifier() : super(const FavoritesState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final animeRaw = prefs.getString(_animeKey);
      final epRaw = prefs.getString(_episodeKey);

      final animes = <FavoriteAnime>[];
      if (animeRaw != null && animeRaw.isNotEmpty) {
        final list = jsonDecode(animeRaw) as List;
        for (final item in list) {
          animes.add(FavoriteAnime.fromJson(item as Map<String, dynamic>));
        }
      }

      final episodes = <FavoriteEpisode>[];
      if (epRaw != null && epRaw.isNotEmpty) {
        final list = jsonDecode(epRaw) as List;
        for (final item in list) {
          episodes.add(FavoriteEpisode.fromJson(item as Map<String, dynamic>));
        }
      }

      state = FavoritesState(animes: animes, episodes: episodes);
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final animeJson = jsonEncode(state.animes.map((a) => a.toJson()).toList());
      final epJson = jsonEncode(state.episodes.map((e) => e.toJson()).toList());
      await prefs.setString(_animeKey, animeJson);
      await prefs.setString(_episodeKey, epJson);
    } catch (e) {
      print('Error persisting favorites: $e');
    }
  }

  /// Toggles favorite status for an anime title
  void toggleAnimeFavorite(Anime anime) {
    final exists = state.isAnimeFav(anime.id);
    List<FavoriteAnime> updated;
    if (exists) {
      updated = state.animes.where((f) => f.anime.id != anime.id).toList();
    } else {
      updated = [
        FavoriteAnime(anime: anime, addedAt: DateTime.now()),
        ...state.animes,
      ];
    }
    state = state.copyWith(animes: updated);
    _persist();
  }

  /// Toggles favorite status for a specific anime episode
  void toggleEpisodeFavorite(Anime anime, Episode episode) {
    final exists = state.isEpisodeFav(episode.id);
    List<FavoriteEpisode> updated;
    if (exists) {
      updated = state.episodes.where((f) => f.episode.id != episode.id).toList();
    } else {
      updated = [
        FavoriteEpisode(
          animeId: anime.id,
          animeTitle: anime.title,
          episode: episode,
          addedAt: DateTime.now(),
        ),
        ...state.episodes,
      ];
    }
    state = state.copyWith(episodes: updated);
    _persist();
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier();
});
