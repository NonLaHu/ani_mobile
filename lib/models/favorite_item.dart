import 'anime.dart';
import 'episode.dart';

/// Represents a favorited anime title
class FavoriteAnime {
  final Anime anime;
  final DateTime addedAt;

  const FavoriteAnime({
    required this.anime,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'anime': anime.toJson(),
        'addedAt': addedAt.toIso8601String(),
      };

  factory FavoriteAnime.fromJson(Map<String, dynamic> json) => FavoriteAnime(
        anime: Anime.fromJson(json['anime'] as Map<String, dynamic>),
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Represents a favorited individual anime episode
class FavoriteEpisode {
  final String animeId;
  final String animeTitle;
  final Episode episode;
  final DateTime addedAt;

  const FavoriteEpisode({
    required this.animeId,
    required this.animeTitle,
    required this.episode,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'animeId': animeId,
        'animeTitle': animeTitle,
        'episode': episode.toJson(),
        'addedAt': addedAt.toIso8601String(),
      };

  factory FavoriteEpisode.fromJson(Map<String, dynamic> json) => FavoriteEpisode(
        animeId: json['animeId'] as String,
        animeTitle: json['animeTitle'] as String,
        episode: Episode.fromJson(json['episode'] as Map<String, dynamic>),
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
