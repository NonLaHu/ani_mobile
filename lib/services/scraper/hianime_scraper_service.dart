import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import '../../models/anime.dart';
import '../../models/episode.dart';
import '../../models/video_source.dart';
import 'anime_scraper_service.dart';
import 'base_scraper.dart';

/// Exact implementation of the ani-mobile v5.1.8 scraper backend.
///
/// Uses HiAnime (hianime.at) API and the ZokoAnime deobfuscator (XOR "otaku-embed-v1")
/// to extract live multi-bitrate HLS streaming playlists (.m3u8).
class HiAnimeScraperService extends BaseScraper implements AnimeScraperService {
  @override
  String get name => 'HiAnime (ani-mobile v5 Engine)';

  static const String baseApi = 'https://hianime.at';
  static const String searchApi = '$baseApi/search?keyword=%s';
  static const String episodesApi = '$baseApi/api/theme/episode/list/%s';
  static const String serversApi = '$baseApi/api/theme/episode/servers?episodeId=%s';

  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  HiAnimeScraperService({super.customDio});

  /// Deobfuscates the `window.__P` blob from ZokoAnime embed player.
  /// Exactly replicates `deobfuscate_blob` from ani-mobile (XOR with "otaku-embed-v1").
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
    try {
      final url = searchApi.replaceFirst('%s', Uri.encodeQueryComponent(query));
      final doc = await fetchHtml(
        url,
        headers: {'User-Agent': defaultUserAgent},
      );

      final list = <Anime>[];
      final elements = doc.querySelectorAll('div.film-detail');

      for (final el in elements) {
        final titleEl = el.querySelector('h3.film-name a');
        if (titleEl == null) continue;

        final title = titleEl.attributes['title'] ?? titleEl.text.trim();
        final href = titleEl.attributes['href'] ?? '';
        if (href.isEmpty) continue;

        // In ani-mobile: id is the slug at the end of href, e.g. "jujutsu-kaisen-tv-534"
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
            synopsis: 'Found on HiAnime (ani-mobile provider).',
            totalEpisodes: int.tryParse(epCount ?? '') ?? 0,
            hasSub: subCount != null && subCount.isNotEmpty,
            hasDub: dubCount != null && dubCount.isNotEmpty,
          ),
        );
      }

      return list;
    } catch (e) {
      print('HiAnime search error: $e');
      return [];
    }
  }

  @override
  Future<List<Anime>> getTrendingAnime() async {
    return searchAnime('jujutsu kaisen');
  }

  @override
  Future<Anime> getAnimeDetails(String animeId) async {
    final searchResults = await searchAnime(animeId.replaceAll('-', ' '));
    if (searchResults.isNotEmpty) {
      return searchResults.first;
    }
    return Anime(
      id: animeId,
      title: animeId,
      coverImage: '',
      synopsis: 'Anime from HiAnime.',
    );
  }

  @override
  Future<List<Episode>> getEpisodes(String animeId, {bool dub = false}) async {
    try {
      // In ani-mobile: ${1##*-} extracts numeric ID after the last hyphen (e.g. "534")
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
      print('HiAnime getEpisodes error: $e');
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

      // In ani-mobile: looks for data-type="$mode" and data-server-name="ZokoAnime"
      final targetType = dub ? 'dub' : 'sub';
      var serverEl = doc.querySelector('.server-item[data-type="$targetType"][data-server-name="ZokoAnime"]');
      serverEl ??= doc.querySelector('.server-item[data-type="$targetType"]');
      serverEl ??= doc.querySelector('.server-item[data-server-name="ZokoAnime"]');
      serverEl ??= doc.querySelector('.server-item');

      if (serverEl == null) {
        throw Exception('No streaming servers found for episode $episodeId');
      }

      final hash = serverEl.attributes['data-hash'] ?? '';
      if (hash.isEmpty) {
        throw Exception('Empty data-hash from streaming server');
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
        ),
      );

      final embedHtml = embedPageResp.data ?? '';
      final pMatch = RegExp(r'window\.__P\s*=\s*["\x27]([^"\x27]*)["\x27]')
          .firstMatch(embedHtml);

      if (pMatch == null) {
        throw Exception('Could not locate window.__P obfuscated payload');
      }

      final blob = pMatch.group(1)!;

      // Step 4: Deobfuscate JSON payload with XOR "otaku-embed-v1"
      final deobfuscatedJson = deobfuscateBlob(blob);
      if (deobfuscatedJson.isEmpty) {
        throw Exception('Failed to deobfuscate player JSON');
      }

      final data = jsonDecode(deobfuscatedJson) as Map<String, dynamic>;
      final masterM3u8Url = data['src'] as String? ?? '';

      if (masterM3u8Url.isEmpty) {
        throw Exception('Stream src (.m3u8) not found in player JSON');
      }

      // Extract subtitles if present
      final subtitles = <SubtitleTrack>[];
      if (data['subtitles'] is List) {
        for (final sub in data['subtitles'] as List) {
          if (sub is Map<String, dynamic>) {
            final src = sub['src'] as String? ?? '';
            final lang = sub['lang'] as String? ?? sub['label'] as String? ?? 'en';
            if (src.isNotEmpty) {
              subtitles.add(SubtitleTrack(url: src, language: lang, label: lang));
            }
          }
        }
      }

      // Extract skip intro timestamps
      int? introStart;
      int? introEnd;
      if (data['skip'] is Map<String, dynamic>) {
        final skip = data['skip'] as Map<String, dynamic>;
        introStart = (skip['intro_start'] as num?)?.toInt();
        introEnd = (skip['intro_end'] as num?)?.toInt();
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
          serverName: 'ZokoAnime (Adaptive)',
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
                serverName: 'ZokoAnime ($quality)',
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
      print('HiAnime getStreamSources error: $e');
      rethrow;
    }
  }
}
