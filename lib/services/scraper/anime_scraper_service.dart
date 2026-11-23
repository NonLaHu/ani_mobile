import '../../models/anime.dart';
import '../../models/episode.dart';
import '../../models/video_source.dart';

/// Exception thrown when an episode is listed in the catalog but has not been
/// uploaded or released yet by streaming hosts.
class EpisodeNotAvailableException implements Exception {
  final String message;
  const EpisodeNotAvailableException([this.message = 'Episode has not been uploaded yet or is unavailable from streaming providers.']);

  @override
  String toString() => message;
}

/// Abstract service interface defining the core contract for anime scrapers
/// in ani-mobile.
abstract class AnimeScraperService {
  /// Scraper identifier name (e.g., 'Primary Provider', 'Secondary Provider')
  String get name;

  /// Searches for anime by query title or keyword
  Future<List<Anime>> searchAnime(String query);

  /// Fetches currently trending or popular anime titles for the home screen
  Future<List<Anime>> getTrendingAnime();

  /// Fetches full details, synopsis, and metadata for a specific anime
  Future<Anime> getAnimeDetails(String animeId);

  /// Fetches the episode list for a specific anime series.
  /// Supports selecting between Subbed and Dubbed episode catalogs.
  Future<List<Episode>> getEpisodes(String animeId, {bool dub = false});

  /// Extracts playable stream sources, quality options, and required HTTP headers
  /// for a specific episode.
  /// Supports selecting between Subbed and Dubbed streams.
  Future<StreamBundle> getStreamSources(String episodeId, {bool dub = false});
}
