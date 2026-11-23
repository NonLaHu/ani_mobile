import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ani_mobile/models/anime.dart';
import 'package:ani_mobile/models/app_update_info.dart';
import 'package:ani_mobile/models/download_task.dart';
import 'package:ani_mobile/models/episode.dart';
import 'package:ani_mobile/models/favorite_item.dart';
import 'package:ani_mobile/models/video_source.dart';
import 'package:ani_mobile/models/watch_history.dart';
import 'package:ani_mobile/providers/download_provider.dart';
import 'package:ani_mobile/providers/playback_settings_provider.dart';
import 'package:ani_mobile/services/download/download_service.dart';
import 'package:ani_mobile/services/scraper/anime_scraper_service.dart';
import 'package:ani_mobile/services/scraper/demo_scraper_service.dart';
import 'package:ani_mobile/services/update/update_service.dart';

void main() {
  group('Data Models', () {
    test('Anime model serialization & deserialization', () {
      const anime = Anime(
        id: 'test-anime',
        title: 'Test Anime Title',
        japaneseTitle: 'テストアニメ',
        coverImage: 'https://example.com/cover.jpg',
        synopsis: 'A test anime synopsis.',
        genres: ['Action', 'Fantasy'],
        rating: 8.5,
        totalEpisodes: 24,
      );

      final json = anime.toJson();
      final fromJson = Anime.fromJson(json);

      expect(fromJson.id, 'test-anime');
      expect(fromJson.title, 'Test Anime Title');
      expect(fromJson.japaneseTitle, 'テストアニメ');
      expect(fromJson.genres, ['Action', 'Fantasy']);
      expect(fromJson.rating, 8.5);
    });

    test('Episode model serialization & deserialization', () {
      const episode = Episode(
        id: 'test-ep-1',
        animeId: 'test-anime',
        number: 1,
        title: 'Episode 1: The Awakening',
        isDub: false,
        isSub: true,
      );

      final json = episode.toJson();
      final fromJson = Episode.fromJson(json);

      expect(fromJson.id, 'test-ep-1');
      expect(fromJson.number, 1);
      expect(fromJson.title, 'Episode 1: The Awakening');
      expect(fromJson.isSub, isTrue);
      expect(fromJson.isDub, isFalse);
    });

    test('WatchHistoryItem progress calculations', () {
      const anime = Anime(
        id: 'test-anime',
        title: 'Test Anime',
        coverImage: 'https://example.com/cover.jpg',
        synopsis: 'Test',
      );
      const episode = Episode(
        id: 'test-ep-1',
        animeId: 'test-anime',
        number: 1,
        title: 'Ep 1',
      );

      final item = WatchHistoryItem(
        anime: anime,
        episode: episode,
        positionSeconds: 600, // 10 minutes
        durationSeconds: 1200, // 20 minutes
        lastWatchedAt: DateTime.now(),
      );

      expect(item.progressPercent, 0.5);
      expect(item.isCompleted, isFalse);
      expect(item.formattedProgress, '10:00 / 20:00');

      final completedItem = item.copyWith(positionSeconds: 1150);
      expect(completedItem.isCompleted, isTrue);
    });
  });

  group('VideoSource & StreamBundle Fallback Logic', () {
    const s1080 = VideoSource(
      url: 'https://stream.example/1080p.mp4',
      quality: '1080p',
      serverName: 'Server1',
      headers: {'Referer': 'https://server1.com/'},
    );
    const s720 = VideoSource(
      url: 'https://stream.example/720p.mp4',
      quality: '720p',
      serverName: 'Server1',
      headers: {'Referer': 'https://server1.com/'},
    );
    const sBackup = VideoSource(
      url: 'https://backup.example/stream.m3u8',
      quality: 'Auto',
      isHls: true,
      serverName: 'BackupServer',
      isBackup: true,
      headers: {'Referer': 'https://backupserver.com/'},
    );

    const bundle = StreamBundle(
      episodeId: 'test-ep-1',
      animeId: 'test-anime',
      episodeNumber: 1,
      sources: [s1080, s720, sBackup],
      introStart: 0,
      introEnd: 85,
    );

    test('Selects exact requested quality when available', () {
      final preferred = bundle.getPreferredSource('720p');
      expect(preferred, equals(s720));
      expect(preferred?.quality, '720p');
    });

    test('Fallback to next available source when primary fails', () {
      final fallback1 = bundle.getNextFallbackSource(s1080);
      expect(fallback1, equals(s720));

      final fallback2 = bundle.getNextFallbackSource(s720);
      expect(fallback2, equals(sBackup));
      expect(fallback2?.isHls, isTrue);
    });
  });

  group('Scraper Service Execution', () {
    final scraper = DemoScraperService();

    test('Searches anime catalog by title', () async {
      final results = await scraper.searchAnime('Jujutsu');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.title.contains('Jujutsu'), isTrue);
    });

    test('Fetches episode catalog with sub and dub separation', () async {
      final subEpisodes = await scraper.getEpisodes('jujutsu-kaisen', dub: false);
      expect(subEpisodes.isNotEmpty, isTrue);
      expect(subEpisodes.first.isSub, isTrue);
      expect(subEpisodes.first.isDub, isFalse);

      final dubEpisodes = await scraper.getEpisodes('jujutsu-kaisen', dub: true);
      expect(dubEpisodes.isNotEmpty, isTrue);
      expect(dubEpisodes.first.isDub, isTrue);
      expect(dubEpisodes.first.isSub, isFalse);
    });

    test('Extracts stream sources with custom HTTP headers', () async {
      final bundle = await scraper.getStreamSources('jujutsu-kaisen-episode-1');
      expect(bundle.sources.isNotEmpty, isTrue);

      final primarySource = bundle.sources.first;
      expect(primarySource.headers.containsKey('Referer'), isTrue);
      expect(primarySource.headers.containsKey('User-Agent'), isTrue);
      expect(primarySource.headers['Referer']!.isNotEmpty, isTrue);
      expect(bundle.introEnd, equals(85));
    });
  });

  group('Download Task Model & Status', () {
    const anime = Anime(
      id: 'solo-leveling',
      title: 'Solo Leveling',
      coverImage: 'https://example.com/cover.jpg',
      synopsis: 'A test synopsis',
    );
    const episode = Episode(
      id: 'ep-1',
      animeId: 'solo-leveling',
      number: 1,
      title: 'Episode 1',
    );
    const source = VideoSource(
      url: 'https://example.com/stream.mp4',
      quality: '1080p',
    );

    test('DownloadTask serialization and deserialization', () {
      final task = DownloadTask(
        id: 'solo-leveling_ep-1',
        anime: anime,
        episode: episode,
        source: source,
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: '/tmp/test.mp4',
        downloadedBytes: 1048576,
        totalBytes: 1048576,
        createdAt: DateTime.now(),
      );

      final json = task.toJson();
      final fromJson = DownloadTask.fromJson(json);

      expect(fromJson.id, equals('solo-leveling_ep-1'));
      expect(fromJson.isCompleted, isTrue);
      expect(fromJson.isDownloading, isFalse);
      expect(fromJson.formattedProgress, equals('100%'));
      expect(fromJson.filePath, equals('/tmp/test.mp4'));
    });

    test('DownloadTask paused state support', () {
      final task = DownloadTask(
        id: 'solo-leveling_ep-1',
        anime: anime,
        episode: episode,
        source: source,
        status: DownloadStatus.paused,
        progress: 0.45,
        downloadedBytes: 45000000,
        totalBytes: 100000000,
        createdAt: DateTime.now(),
      );

      expect(task.isPaused, isTrue);
      expect(task.isDownloading, isFalse);
      expect(task.isCompleted, isFalse);
      expect(task.formattedProgress, '45%');

      final json = task.toJson();
      final fromJson = DownloadTask.fromJson(json);
      expect(fromJson.status, DownloadStatus.paused);
      expect(fromJson.isPaused, isTrue);
    });
    test('EpisodeNotAvailableException carries informative message', () {
      const ex = EpisodeNotAvailableException('Episode not yet released');
      expect(ex.message, 'Episode not yet released');
      expect(ex.toString(), 'Episode not yet released');
    });
  });

  group('Favorites Models', () {
    const anime = Anime(
      id: 'frieren',
      title: 'Frieren: Beyond Journey\'s End',
      coverImage: 'https://example.com/frieren.jpg',
      synopsis: 'An elf mage journey',
    );
    const episode = Episode(
      id: 'frieren-ep-1',
      animeId: 'frieren',
      number: 1,
      title: 'The Journey\'s End',
    );

    test('FavoriteAnime model serialization & deserialization', () {
      final now = DateTime.now();
      final favAnime = FavoriteAnime(anime: anime, addedAt: now);
      final json = favAnime.toJson();
      final fromJson = FavoriteAnime.fromJson(json);

      expect(fromJson.anime.id, equals('frieren'));
      expect(fromJson.anime.title, equals('Frieren: Beyond Journey\'s End'));
    });

    test('FavoriteEpisode model serialization & deserialization', () {
      final now = DateTime.now();
      final favEp = FavoriteEpisode(
        animeId: anime.id,
        animeTitle: anime.title,
        episode: episode,
        addedAt: now,
      );
      final json = favEp.toJson();
      final fromJson = FavoriteEpisode.fromJson(json);

      expect(fromJson.animeId, equals('frieren'));
      expect(fromJson.animeTitle, equals('Frieren: Beyond Journey\'s End'));
      expect(fromJson.episode.number, equals(1));
    });
  });

  group('PlaybackSettings & Subtitles', () {
    test('PlaybackSettings defaults and copyWith', () {
      const defaultSettings = PlaybackSettings();
      expect(defaultSettings.enableHardwareAcceleration, isFalse);
      expect(defaultSettings.subtitlesEnabled, isTrue);
      expect(defaultSettings.subtitleFontSize, equals(22.0));

      final custom = defaultSettings.copyWith(
        enableHardwareAcceleration: true,
        subtitlesEnabled: false,
        subtitleFontSize: 28.0,
      );
      expect(custom.enableHardwareAcceleration, isTrue);
      expect(custom.subtitlesEnabled, isFalse);
      expect(custom.subtitleFontSize, equals(28.0));
    });

    test('Local Episode Pagination Slicing for shows > 30 episodes', () {
      // Simulate 75 episodes (like Fullmetal Alchemist or Bleach arc)
      final dummyEpisodes = List.generate(
        75,
        (i) => Episode(
          id: 'ep-$i',
          animeId: 'one-piece',
          number: i + 1,
          title: 'Episode ${i + 1}',
        ),
      );

      const pageSize = 30;
      final totalPages = (dummyEpisodes.length / pageSize).ceil();
      expect(totalPages, equals(3));

      // Page 1: 0..30 (Ep 1 to 30)
      final page1 = dummyEpisodes.sublist(0, 30);
      expect(page1.length, equals(30));
      expect(page1.first.number, equals(1));
      expect(page1.last.number, equals(30));

      // Page 2: 30..60 (Ep 31 to 60)
      final page2 = dummyEpisodes.sublist(30, 60);
      expect(page2.length, equals(30));
      expect(page2.first.number, equals(31));
      expect(page2.last.number, equals(60));

      // Page 3: 60..75 (Ep 61 to 75)
      final page3 = dummyEpisodes.sublist(60, 75);
      expect(page3.length, equals(15));
      expect(page3.first.number, equals(61));
      expect(page3.last.number, equals(75));
    });

    test('DownloadState isDownloaded avoids false positives for One Piece', () {
      final diskFiles = <DiskVideoFile>[
        DiskVideoFile(
          file: File('/storage/ani_mobile/Jujutsu Kaisen/EP1_SUB.mp4'),
          animeTitle: 'Jujutsu Kaisen',
          episodeNumber: 1,
          isDub: false,
          sizeBytes: 1024 * 1024 * 50,
          modifiedAt: DateTime.now(),
        ),
      ];

      final state = DownloadState(diskFiles: diskFiles);

      // Episode 1 from completely different anime should NOT match even if episode number is 1
      final isOnePieceDownloaded = state.isDownloaded(
        'one-piece-ep-1',
        animeTitle: 'One Piece',
        episodeNumber: 1,
        isDub: false,
      );
      expect(isOnePieceDownloaded, isFalse);

      // Episode 4 of Jujutsu Kaisen should NOT match episode 1
      final isJJK4Downloaded = state.isDownloaded(
        'jjk-4',
        animeTitle: 'Jujutsu Kaisen',
        episodeNumber: 4,
        isDub: false,
      );
      expect(isJJK4Downloaded, isFalse);
    });

    test('AppUpdateInfo serialization & mock update validation', () async {
      const info = AppUpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '1.1.0',
        hasUpdate: true,
        releaseTitle: 'v1.1.0 Release',
        releaseNotes: '• New features',
        downloadUrl: 'https://example.com',
      );

      final json = info.toJson();
      final fromJson = AppUpdateInfo.fromJson(json);

      expect(fromJson.currentVersion, equals('1.0.0'));
      expect(fromJson.latestVersion, equals('1.1.0'));
      expect(fromJson.hasUpdate, isTrue);
      expect(fromJson.releaseTitle, equals('v1.1.0 Release'));

      final updateService = UpdateService();
      final mockInfo = await updateService.checkForUpdates(forceMockUpdate: true);
      expect(mockInfo.hasUpdate, isTrue);
      expect(mockInfo.latestVersion, equals('1.1.0'));
      expect(mockInfo.releaseNotes.isNotEmpty, isTrue);
    });
  });
}
