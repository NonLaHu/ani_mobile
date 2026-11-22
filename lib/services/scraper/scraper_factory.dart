import 'anime_scraper_service.dart';
import 'demo_scraper_service.dart';
import 'hianime_scraper_service.dart';
import 'live_scraper_service.dart';

enum ScraperType {
  hianime,
  demo,
  live,
}

/// Factory utility to instantiate and switch scraper providers
class ScraperFactory {
  static AnimeScraperService getScraper(ScraperType type) {
    switch (type) {
      case ScraperType.hianime:
        return HiAnimeScraperService();
      case ScraperType.demo:
        return DemoScraperService();
      case ScraperType.live:
        return LiveScraperService();
    }
  }
}
