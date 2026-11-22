import '../../models/anime.dart';
import '../../models/episode.dart';
import '../../models/video_source.dart';

/// Abstract service interface defining the core contract for anime scrapers
/// inspired by the command-line utility `ani-mobile`.
abstract class AnimeScraperService {
  /// Scraper identifier name (e.g., 'DemoScraper', 'GogoAnime', 'AllAnime')
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
