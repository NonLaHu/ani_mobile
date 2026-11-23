import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import '../../models/anime.dart';
import '../../models/episode.dart';
import '../../models/video_source.dart';
import 'anime_scraper_service.dart';
import 'base_scraper.dart';

/// Primary online scraper service.
///
/// Uses primary provider API and stream deobfuscator (XOR "otaku-embed-v1")
/// to extract live multi-bitrate HLS streaming playlists (.m3u8).
class HiAnimeScraperService extends BaseScraper implements AnimeScraperService {
  @override
  String get name => 'Primary Provider';

  static const String baseApi = 'https://hianime.fm';
  static const String searchApi = '$baseApi/search?keyword=%s';
  static const String episodesApi = '$baseApi/api/theme/episode/list/%s';
  static const String serversApi = '$baseApi/api/theme/episode/servers?episodeId=%s';

  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  HiAnimeScraperService({super.customDio});

  /// Deobfuscates the `window.__P` blob from embed player.
  /// Decodes base64 payload with XOR "otaku-embed-v1".
  static String deobfuscateBlob(String base64Blob) {
    try {
      final rawBytes = base64Decode(base64Blob.trim());
      const key = 'otaku-embed-v1';
      final keyBytes = utf8.encode(key);

      final resultBytes = List<int>.generate(
        rawBytes.length,
        (i) => rawBytes[i] ^ keyBytes[i % keyBytes.length],
      );

      return utf8.decode(resultBytes);
    } catch (e) {
      print('Deobfuscation error: $e');
      return '';
    }
  }

  @override
  Future<List<Anime>> searchAnime(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = searchApi.replaceFirst('%s', Uri.encodeQueryComponent(query));
      final doc = await fetchHtml(
        url,
        headers: {'User-Agent': defaultUserAgent},
      );

      // Remove sidebar before querying film details to prevent top 10/trending markup contamination
      doc.querySelector('#main-sidebar')?.remove();

      final list = <Anime>[];
      final elements = doc.querySelectorAll('div.film-detail');

      for (final el in elements) {
        final titleEl = el.querySelector('h3.film-name a');
        if (titleEl == null) continue;

        final title = titleEl.attributes['title'] ?? titleEl.text.trim();
        final href = titleEl.attributes['href'] ?? '';
        if (href.isEmpty) continue;

        // Id is the slug at the end of href, e.g. "jujutsu-kaisen-tv-534"
        final slug = href.split('/').last.split('?').first;

        // Poster image from parent film-poster if available
        final parent = el.parent;
        final imgEl = parent?.querySelector('div.film-poster img');
        final cover = imgEl?.attributes['data-src'] ??
            imgEl?.attributes['src'] ??
            '';

        // Check sub/dub badges
        final subCount = parent?.querySelector('.tick-sub')?.text.trim();
        final dubCount = parent?.querySelector('.tick-dub')?.text.trim();
        final epCount = parent?.querySelector('.tick-eps')?.text.trim();

        list.add(
          Anime(
            id: slug,
            title: title,
            coverImage: cover,
            synopsis: 'Available on Primary Provider.',
            totalEpisodes: int.tryParse(epCount ?? '') ?? 0,
            hasSub: subCount != null && subCount.isNotEmpty,
            hasDub: dubCount != null && dubCount.isNotEmpty,
          ),
        );
      }

      return list;
    } catch (e) {
      print('Primary Provider search error: $e');
      return [];
    }
  }

  @override
  Future<List<Anime>> getTrendingAnime() async {
    return searchAnime('jujutsu kaisen');
  }

  @override
  Future<Anime> getAnimeDetails(String animeId) async {
    // Attempt 1: Fetch exact anime page directly from slug (e.g. https://hianime.to/anime-slug-1234)
    try {
      final doc = await fetchHtml(
        '$baseApi/$animeId',
        headers: {'User-Agent': defaultUserAgent},
      );
      final title = doc.querySelector('.anisc-detail h2.film-name')?.text.trim() ??
          doc.querySelector('h2.film-name')?.text.trim();
      if (title != null && title.isNotEmpty) {
        final imgEl = doc.querySelector('.film-poster img');
        final cover = imgEl?.attributes['data-src'] ?? imgEl?.attributes['src'] ?? '';
        final synopsis = doc.querySelector('.film-description .text')?.text.trim() ?? '';
        final genres = doc.querySelectorAll('.item-list a').map((a) => a.text.trim()).toList();
        final japTitle = doc.querySelector('.anisc-info .item:has(.item-head) .name')?.text.trim();

        return Anime(
          id: animeId,
          title: title,
          japaneseTitle: japTitle,
          coverImage: cover,
          synopsis: synopsis.isNotEmpty ? synopsis : 'Available on Primary Provider.',
          genres: genres,
        );
      }
    } catch (_) {}

    // Attempt 2: Search by query and strictly match the exact anime id / slug
    final searchResults = await searchAnime(animeId.replaceAll(RegExp(r'-\d+$'), '').replaceAll('-', ' '));
    if (searchResults.isNotEmpty) {
      final match = searchResults.firstWhere(
        (a) => a.id == animeId,
        orElse: () => searchResults.first,
      );
      return match;
    }

    return Anime(
      id: animeId,
      title: animeId,
      coverImage: '',
      synopsis: 'Available on Primary Provider.',
    );
  }

  @override
  Future<List<Episode>> getEpisodes(String animeId, {bool dub = false}) async {
    if (animeId.trim().isEmpty) return [];
    try {
      // Extract numeric ID after the last hyphen (e.g. "534")
      final idParts = animeId.split('-');
      final numericId = idParts.last;

      final url = episodesApi.replaceFirst('%s', numericId);
      final response = await dio.get<Map<String, dynamic>>(
        url,
        options: Options(headers: {'User-Agent': defaultUserAgent}),
      );

      final data = response.data;
      if (data == null || data['html'] == null) {
        return [];
      }

      final htmlContent = data['html'] as String;
      final doc = Document.html(htmlContent);
      final links = doc.querySelectorAll('a.ep-item');

      final episodes = <Episode>[];
      for (final a in links) {
        final epNumberStr = a.attributes['data-number'] ?? '1';
        final epNumber = int.tryParse(epNumberStr) ?? episodes.length + 1;
        final epId = a.attributes['data-id'] ?? '';
        final title = a.attributes['title'] ?? 'Episode $epNumber';

        if (epId.isNotEmpty) {
          episodes.add(
            Episode(
              id: epId, // numeric episode id required for servers API
              animeId: animeId,
              number: epNumber,
              title: title.isNotEmpty ? title : 'Episode $epNumber',
              isDub: dub,
              isSub: !dub,
            ),
          );
        }
      }

      return episodes;
    } catch (e) {
      print('Primary Provider getEpisodes error: $e');
      return [];
    }
  }

  @override
  Future<StreamBundle> getStreamSources(String episodeId, {bool dub = false}) async {
    try {
      // Step 1: Fetch servers list HTML from servers API
      final url = serversApi.replaceFirst('%s', episodeId);
      final resp = await dio.get<Map<String, dynamic>>(
        url,
        options: Options(headers: {'User-Agent': defaultUserAgent}),
      );

      final htmlContent = resp.data?['html'] as String? ?? '';
      final doc = Document.html(htmlContent);

      final targetType = dub ? 'dub' : 'sub';
      var serverEl = doc.querySelector('.server-item[data-type="$targetType"][data-server-name="ZokoAnime"]');
      serverEl ??= doc.querySelector('.server-item[data-type="$targetType"]');
      serverEl ??= doc.querySelector('.server-item[data-server-name="ZokoAnime"]');
      serverEl ??= doc.querySelector('.server-item');

      if (serverEl == null) {
        throw EpisodeNotAvailableException(
            'No streaming servers found for episode $episodeId. It may not have been released or uploaded yet. Try turning on a VPN if you think it has already aired.');
      }

      final hash = serverEl.attributes['data-hash'] ?? '';
      if (hash.isEmpty) {
        throw EpisodeNotAvailableException('Streaming server has no playable video hash for episode $episodeId. Try turning on a VPN if it has already aired.');
      }

      // Step 2: Base64 decode embed URL
      final embedUrl = utf8.decode(base64Decode(hash));
      final embedUri = Uri.parse(embedUrl);
      final embedReferer = '${embedUri.scheme}://${embedUri.host}/';

      // Step 3: Fetch embed page and extract window.__P
      final embedPageResp = await dio.get<String>(
        embedUrl,
        options: Options(
          headers: {
            'User-Agent': defaultUserAgent,
            'Referer': embedReferer,
          },
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final embedHtml = embedPageResp.data ?? '';

      // Check for explicit 404 / unreleased episode notices in embed host
      if (embedPageResp.statusCode == 404 ||
          embedHtml.contains("We couldn't find anything to play here") ||
          embedHtml.contains('Error</span><span class="code">404') ||
          embedHtml.contains('Not <span class="stroke">found')) {
        throw const EpisodeNotAvailableException(
            'This episode has not been uploaded yet or is not currently available from the streaming host. Try turning on a VPN if you think it has already aired.');
      }

      final pMatch = RegExp(r'window\.__P\s*=\s*["\x27]([^"\x27]*)["\x27]')
          .firstMatch(embedHtml);

      String masterM3u8Url = '';
      final subtitles = <SubtitleTrack>[];
      int? introStart;
      int? introEnd;

      if (pMatch != null) {
        final blob = pMatch.group(1)!;
        // Step 4: Deobfuscate JSON payload with XOR "otaku-embed-v1"
        final deobfuscatedJson = deobfuscateBlob(blob);
        if (deobfuscatedJson.isNotEmpty) {
          try {
            final data = jsonDecode(deobfuscatedJson) as Map<String, dynamic>;
            masterM3u8Url = data['src'] as String? ?? data['file'] as String? ?? '';

            // Extract subtitles if present
            if (data['subtitles'] is List) {
              for (final sub in data['subtitles'] as List) {
                if (sub is Map<String, dynamic>) {
                  final src = sub['file'] as String? ?? sub['src'] as String? ?? sub['url'] as String? ?? '';
                  final lang = sub['label'] as String? ?? sub['lang'] as String? ?? 'English';
                  if (src.isNotEmpty) {
                    subtitles.add(SubtitleTrack(url: src, language: lang, label: lang));
                  }
                }
              }
            }

            // Extract skip intro timestamps
            if (data['skip'] is Map<String, dynamic>) {
              final skip = data['skip'] as Map<String, dynamic>;
              introStart = (skip['intro_start'] as num?)?.toInt();
              introEnd = (skip['intro_end'] as num?)?.toInt();
            }
          } catch (e) {
            print('Deobfuscated JSON parse note: $e');
          }
        }
      }

      // Fallback: search for direct .m3u8 URL in embed HTML
      if (masterM3u8Url.isEmpty) {
        final m3u8Match = RegExp(r'["\x27](https?://[^"\x27]+\.m3u8[^"\x27]*)["\x27]')
            .firstMatch(embedHtml);
        if (m3u8Match != null) {
          masterM3u8Url = m3u8Match.group(1)!;
        }
      }

      if (masterM3u8Url.isEmpty) {
        throw const EpisodeNotAvailableException(
            'Could not locate playable stream source in embed player. Episode may be upcoming or not yet uploaded. Try turning on a VPN if you think it has already aired.');
      }

      // Step 5: Fetch master playlist to parse qualities (1080p, 720p, etc.)
      final playlistHeaders = {
        'User-Agent': defaultUserAgent,
        'Referer': embedReferer,
      };

      final playlistResp = await dio.get<String>(
        masterM3u8Url,
        options: Options(
          headers: playlistHeaders,
          responseType: ResponseType.plain,
        ),
      );

      final playlistText = playlistResp.data ?? '';
      final sources = <VideoSource>[];

      // Add Master playlist as Auto option
      sources.add(
        VideoSource(
          url: masterM3u8Url,
          quality: 'Auto',
          isHls: true,
          serverName: 'Stream Server 1 (Adaptive)',
          headers: playlistHeaders,
        ),
      );

      // Parse individual resolution streams from master m3u8
      final streamLines = playlistText.split('\n');
      final baseM3u8Dir = masterM3u8Url.substring(0, masterM3u8Url.lastIndexOf('/'));

      for (var i = 0; i < streamLines.length; i++) {
        final line = streamLines[i].trim();
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          final resMatch = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line);
          final quality = resMatch != null ? '${resMatch.group(1)}p' : 'Unknown';

          if (i + 1 < streamLines.length) {
            var streamUrl = streamLines[i + 1].trim();
            if (!streamUrl.startsWith('http')) {
              streamUrl = '$baseM3u8Dir/$streamUrl';
            }

            sources.add(
              VideoSource(
                url: streamUrl,
                quality: quality,
                isHls: true,
                serverName: 'Stream Server 1 ($quality)',
                headers: playlistHeaders,
              ),
            );
          }
        }
      }

      return StreamBundle(
        episodeId: episodeId,
        animeId: episodeId,
        episodeNumber: 1,
        sources: sources,
        subtitles: subtitles,
        introStart: introStart ?? 0,
        introEnd: introEnd ?? 85,
      );
    } catch (e) {
      print('Primary Provider getStreamSources error: $e');
      rethrow;
    }
  }
}
