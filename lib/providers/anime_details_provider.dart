import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import 'scraper_provider.dart';

/// Global preference for default audio mode (sub vs dub)
final preferredDubProvider = StateProvider<bool>((ref) => false);

/// Global preference for default stream quality ('Auto', '1080p', '720p', '480p')
final preferredQualityProvider = StateProvider<String>((ref) => 'Auto');

/// Tracks whether Dubbed audio is currently toggled for a specific anime
final isDubSelectedProvider =
    StateProvider.family<bool, String>((ref, animeId) {
  // Default to global preference
  return ref.watch(preferredDubProvider);
});

/// Tracks episode ordering preference (true = 1 -> N, false = N -> 1)
final episodeOrderAscendingProvider = StateProvider<bool>((ref) => true);

/// Fetches comprehensive anime metadata
final animeDetailsProvider =
    FutureProvider.family<Anime, String>((ref, animeId) async {
  final scraper = ref.watch(scraperServiceProvider);
  return scraper.getAnimeDetails(animeId);
});

/// Fetches the episode list for an anime, automatically updating when Dub/Sub is toggled
final episodesProvider =
    FutureProvider.family<List<Episode>, String>((ref, animeId) async {
  final scraper = ref.watch(scraperServiceProvider);
  final isDub = ref.watch(isDubSelectedProvider(animeId));
  return scraper.getEpisodes(animeId, dub: isDub);
});
