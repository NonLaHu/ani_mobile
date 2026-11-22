import 'dart:async';
import '../../models/anime.dart';
import '../../models/episode.dart';
import '../../models/video_source.dart';
import 'anime_scraper_service.dart';
import 'base_scraper.dart';

/// Demo scraper service that provides guaranteed playable streams,
/// realistic anime catalogs, and complete demonstrations of HTTP header injection,
/// quality selection, episode navigation, and fallback recovery.
class DemoScraperService extends BaseScraper implements AnimeScraperService {
  @override
  String get name => 'Demo Scraper (High Quality)';

  /// Built-in rich anime catalog for instant out-of-the-box streaming and UI verification
  static final List<Anime> _catalog = [
    const Anime(
      id: 'jujutsu-kaisen',
      title: 'Jujutsu Kaisen',
      japaneseTitle: '呪術廻戦',
      coverImage:
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&auto=format&fit=crop&q=80',
      bannerImage:
          'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=1200&auto=format&fit=crop&q=80',
      synopsis:
          'A boy swallows a cursed talisman - the finger of a demon - and becomes cursed himself. He enters a shaman\'s school to be able to locate the demon\'s other body parts and thus exorcise himself.',
      genres: ['Action', 'Fantasy', 'Supernatural', 'Shounen'],
      status: 'Ongoing',
      totalEpisodes: 24,
      releaseYear: '2020',
      type: 'TV',
      hasSub: true,
      hasDub: true,
      rating: 8.7,
    ),
    const Anime(
      id: 'frieren-beyond-journeys-end',
      title: "Frieren: Beyond Journey's End",
      japaneseTitle: '葬送のフリーレン',
      coverImage:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80',
      bannerImage:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200&auto=format&fit=crop&q=80',
      synopsis:
          'After the party of heroes defeated the Demon King, they restored peace to the land and returned to lives of solitude. Generations pass, and the elven mage Frieren comes face to face with humanity\'s mortality.',
      genres: ['Adventure', 'Drama', 'Fantasy'],
      status: 'Completed',
      totalEpisodes: 28,
      releaseYear: '2023',
      type: 'TV',
      hasSub: true,
      hasDub: true,
      rating: 9.1,
    ),
    const Anime(
      id: 'solo-leveling',
      title: 'Solo Leveling',
      japaneseTitle: '俺だけレベルアップな件',
      coverImage:
          'https://images.unsplash.com/photo-1563089145-599997674d42?w=600&auto=format&fit=crop&q=80',
      bannerImage:
          'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=1200&auto=format&fit=crop&q=80',
      synopsis:
          'In a world where hunters with supernatural powers fight deadly monsters to protect humanity, an inveterately weak hunter named Sung Jinwoo finds himself in a struggle for survival.',
      genres: ['Action', 'Adventure', 'Fantasy'],
      status: 'Completed',
      totalEpisodes: 12,
      releaseYear: '2024',
      type: 'TV',
      hasSub: true,
      hasDub: true,
      rating: 8.5,
    ),
    const Anime(
      id: 'demon-slayer-kimetsu-no-yaiba',
      title: 'Demon Slayer: Kimetsu no Yaiba',
      japaneseTitle: '鬼滅の刃',
      coverImage:
          'https://images.unsplash.com/photo-1563089145-599997674d42?w=600&auto=format&fit=crop&q=80',
      bannerImage:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200&auto=format&fit=crop&q=80',
      synopsis:
          'A family is attacked by demons and only two members survive - Tanjiro and his sister Nezuko, who is turning into a demon. Tanjiro sets out to become a demon slayer to avenge his family and cure his sister.',
      genres: ['Action', 'Fantasy', 'Historical', 'Shounen'],
      status: 'Ongoing',
      totalEpisodes: 26,
      releaseYear: '2019',
      type: 'TV',
      hasSub: true,
      hasDub: true,
      rating: 8.6,
    ),
    const Anime(
      id: 'attack-on-titan',
      title: 'Attack on Titan',
      japaneseTitle: '進撃の巨人',
      coverImage:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      bannerImage:
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=1200&auto=format&fit=crop&q=80',
      synopsis:
          'After his hometown is destroyed and his mother is killed, young Eren Jaeger vows to cleanse the earth of the giant humanoid Titans that have brought humanity to the brink of extinction.',
      genres: ['Action', 'Drama', 'Fantasy', 'Mystery'],
      status: 'Completed',
      totalEpisodes: 87,
      releaseYear: '2013',
      type: 'TV',
      hasSub: true,
      hasDub: true,
      rating: 9.0,
    ),
    const Anime(
      id: 'cyberpunk-edgerunners',
      title: 'Cyberpunk: Edgerunners',
      japaneseTitle: 'サイバーパンク エッジランナーズ',
      coverImage:
          'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
      bannerImage:
          'https://images.unsplash.com/photo-1563089145-599997674d42?w=1200&auto=format&fit=crop&q=80',
      synopsis:
          'A street kid trying to survive in a technology and body modification-obsessed city of the future. Having everything to lose, he chooses to stay alive by becoming an edgerunner: a mercenary outlaw.',
      genres: ['Action', 'Sci-Fi', 'Psychological'],
      status: 'Completed',
      totalEpisodes: 10,
      releaseYear: '2022',
      type: 'TV',
      hasSub: true,
      hasDub: true,
      rating: 8.6,
    ),
  ];

  @override
  Future<List<Anime>> searchAnime(String query) async {
    // Simulate brief network latency for realistic UX response
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _catalog;

    return _catalog.where((anime) {
      final titleMatch = anime.title.toLowerCase().contains(normalized);
      final altMatch =
          anime.japaneseTitle?.toLowerCase().contains(normalized) ?? false;
      final genreMatch =
          anime.genres.any((g) => g.toLowerCase().contains(normalized));
      return titleMatch || altMatch || genreMatch;
    }).toList();
  }

  @override
  Future<List<Anime>> getTrendingAnime() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<Anime>.from(_catalog);
  }

  @override
  Future<Anime> getAnimeDetails(String animeId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _catalog.firstWhere(
      (a) => a.id == animeId,
      orElse: () => _catalog.first,
    );
  }

  @override
  Future<List<Episode>> getEpisodes(String animeId, {bool dub = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final anime = _catalog.firstWhere(
      (a) => a.id == animeId,
      orElse: () => _catalog.first,
    );

    final episodes = <Episode>[];
    final count = anime.totalEpisodes > 0 ? anime.totalEpisodes : 12;

    for (var i = 1; i <= count; i++) {
      episodes.add(
        Episode(
          id: '${anime.id}-episode-$i${dub ? '-dub' : '-sub'}',
          animeId: anime.id,
          number: i,
          title: 'Episode $i: ${_getEpisodeTitle(anime.id, i)}',
          thumbnail: anime.coverImage,
          isFiller: i % 7 == 0,
          isDub: dub,
          isSub: !dub,
          airDate: '202${(i % 4) + 1}-0${(i % 9) + 1}-12',
        ),
      );
    }
    return episodes;
  }

  @override
  Future<StreamBundle> getStreamSources(String episodeId, {bool dub = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    // Parse episode number from ID if possible
    final epNumMatch = RegExp(r'episode-(\d+)').firstMatch(episodeId);
    final epNumber =
        epNumMatch != null ? int.tryParse(epNumMatch.group(1)!) ?? 1 : 1;
    final animeId = episodeId.split('-episode-').first;

    // High quality, stable public HLS streams and direct video sources
    // with custom Referer and User-Agent headers required by streaming CDNs.
    final headers = buildHeaders(
      referer: 'https://megacloud.tv/embed-2/e-1/?z=',
      userAgent: BaseScraper.defaultUserAgent,
      extra: {
        'Origin': 'https://megacloud.tv',
        'X-Requested-With': 'XMLHttpRequest',
      },
    );

    final sources = <VideoSource>[
      // Auto Multi-bitrate HLS Stream (Apple HLS test stream - adaptive bitrates)
      VideoSource(
        url:
            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
        quality: 'Auto',
        isHls: true,
        serverName: 'MegaCloud (Primary)',
        headers: headers,
      ),
      // 1080p Stream
      VideoSource(
        url:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        quality: '1080p',
        isHls: false,
        serverName: 'Vidstreaming (1080p)',
        headers: headers,
      ),
      // 720p Stream
      VideoSource(
        url:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        quality: '720p',
        isHls: false,
        serverName: 'Vidstreaming (720p)',
        headers: headers,
      ),
      // 480p Stream (Fast loading fallback)
      VideoSource(
        url:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        quality: '480p',
        isHls: false,
        serverName: 'StreamSB (480p Backup)',
        headers: headers,
        isBackup: true,
      ),
    ];

    return StreamBundle(
      episodeId: episodeId,
      animeId: animeId,
      episodeNumber: epNumber,
      sources: sources,
      introStart: 0,
      introEnd: 85, // 85-second intro skip (standard anime opening duration)
      outroStart: 1320,
      outroEnd: 1410,
    );
  }

  String _getEpisodeTitle(String animeId, int num) {
    const titles = [
      'The Beginning of the End',
      'Awakening of Power',
      'Cursed Bloodlines',
      'The Iron Will',
      'Shadows in the Mist',
      'Reckoning at Dawn',
      'Crossroads of Destiny',
      'Unleashed Fury',
      'Echoes of the Past',
      'Battle for Tomorrow',
      'The Final Stand',
      'A New Dawn',
    ];
    return titles[(num - 1) % titles.length];
  }
}
