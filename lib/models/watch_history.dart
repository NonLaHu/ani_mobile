import 'anime.dart';
import 'episode.dart';

/// Represents a user's playback history and resume state for an episode
class WatchHistoryItem {
  final Anime anime;
  final Episode episode;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime lastWatchedAt;

  const WatchHistoryItem({
    required this.anime,
    required this.episode,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.lastWatchedAt,
  });

  double get progressPercent {
    if (durationSeconds <= 0) return 0.0;
    final percent = positionSeconds / durationSeconds;
    return percent.clamp(0.0, 1.0);
  }

  bool get isCompleted => progressPercent > 0.92;

  String get formattedProgress {
    final posMin = (positionSeconds ~/ 60).toString().padLeft(2, '0');
    final posSec = (positionSeconds % 60).toString().padLeft(2, '0');
    final durMin = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final durSec = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$posMin:$posSec / $durMin:$durSec';
  }

  Map<String, dynamic> toJson() => {
    'anime': anime.toJson(),
    'episode': episode.toJson(),
    'positionSeconds': positionSeconds,
    'durationSeconds': durationSeconds,
    'lastWatchedAt': lastWatchedAt.toIso8601String(),
  };

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) => WatchHistoryItem(
    anime: Anime.fromJson(json['anime'] as Map<String, dynamic>),
    episode: Episode.fromJson(json['episode'] as Map<String, dynamic>),
    positionSeconds: json['positionSeconds'] as int? ?? 0,
    durationSeconds: json['durationSeconds'] as int? ?? 0,
    lastWatchedAt: json['lastWatchedAt'] != null
        ? DateTime.tryParse(json['lastWatchedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  WatchHistoryItem copyWith({
    Anime? anime,
    Episode? episode,
    int? positionSeconds,
    int? durationSeconds,
    DateTime? lastWatchedAt,
  }) {
    return WatchHistoryItem(
      anime: anime ?? this.anime,
      episode: episode ?? this.episode,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
    );
  }
}
