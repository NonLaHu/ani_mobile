import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/scraper/anime_scraper_service.dart';
import '../services/scraper/scraper_factory.dart';

/// Provider for current scraper engine type (defaults to Primary Provider)
final scraperTypeProvider = StateProvider<ScraperType>((ref) {
  return ScraperType.hianime;
});

/// Active scraper service instance reacting to scraper type switches
final scraperServiceProvider = Provider<AnimeScraperService>((ref) {
  final type = ref.watch(scraperTypeProvider);
  return ScraperFactory.getScraper(type);
});
