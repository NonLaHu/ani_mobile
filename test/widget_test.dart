import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_mobile/main.dart';
import 'package:ani_mobile/screens/details_screen.dart';
import 'package:ani_mobile/screens/downloads_screen.dart';
import 'package:ani_mobile/theme/app_theme.dart';
import 'package:ani_mobile/models/anime.dart';
import 'package:ani_mobile/models/episode.dart';
import 'package:ani_mobile/models/video_source.dart';
import 'package:ani_mobile/providers/scraper_provider.dart';
import 'package:ani_mobile/services/scraper/scraper_factory.dart';
import 'package:ani_mobile/widgets/download_resolution_sheet.dart';
import 'package:ani_mobile/widgets/loading_cycle.dart';

void main() {
  testWidgets('App renders Home Screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scraperTypeProvider.overrideWith((ref) => ScraperType.demo),
        ],
        child: const AniMobileApp(),
      ),
    );

    // Let the initial async futures and animations complete
    await tester.pumpAndSettle();

    // Verify app brand text is rendered inside RichText
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('ani-mobile'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('DownloadsScreen renders empty state gracefully', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(
          child: DownloadsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Downloaded Anime'), findsOneWidget);
    expect(find.text('No Downloaded Videos Found'), findsOneWidget);
  });

  testWidgets('DetailsScreen renders episode items cleanly without ListTile assertions', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProviderScope(
          overrides: [
            scraperTypeProvider.overrideWith((ref) => ScraperType.demo),
          ],
          child: const DetailsScreen(animeId: 'jujutsu-kaisen'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Episodes section and list tiles render without assertions
    expect(find.text('Episodes'), findsOneWidget);
    expect(find.textContaining('Episode 1:'), findsWidgets);
  });

  testWidgets('LoadingCycle and LoadingCycleOverlay render and animate cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: LoadingCycleOverlay(
            title: 'Opening Stream',
            subtitle: 'Connecting to server...',
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Opening Stream'), findsOneWidget);
    expect(find.text('Connecting to server...'), findsOneWidget);
    expect(find.byType(LoadingCycle), findsOneWidget);

    // Pump further along animation cycle
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LoadingCycle), findsOneWidget);
  });

  testWidgets('DownloadResolutionSheet displays qualities and subtitle indicator', (WidgetTester tester) async {
    const anime = Anime(id: 'jujutsu', title: 'Jujutsu Kaisen', coverImage: '', synopsis: '');
    const episode = Episode(id: 'ep-1', animeId: 'jujutsu', number: 1, title: 'Episode 1');
    const bundle = StreamBundle(
      episodeId: 'ep-1',
      animeId: 'jujutsu',
      episodeNumber: 1,
      sources: [
        VideoSource(url: 'https://video.test/1080p.m3u8', quality: '1080p'),
        VideoSource(url: 'https://video.test/720p.m3u8', quality: '720p'),
      ],
      subtitles: [
        SubtitleTrack(url: 'https://video.test/sub.vtt', language: 'eng', label: 'English'),
      ],
    );

    VideoSource? selectedSource;
    String? selectedSubUrl;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: DownloadResolutionSheet(
            anime: anime,
            episode: episode,
            preloadedBundle: bundle,
            onQualitySelected: (source, subUrl) {
              selectedSource = source;
              selectedSubUrl = subUrl;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Download Episode 1'), findsOneWidget);
    expect(find.textContaining('Subtitles (.vtt) will be saved'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);

    // Tap 1080p
    await tester.tap(find.text('1080p'));
    await tester.pumpAndSettle();

    expect(selectedSource?.quality, equals('1080p'));
    expect(selectedSubUrl, equals('https://video.test/sub.vtt'));
  });
}
