import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_mobile/main.dart';
import 'package:ani_mobile/screens/details_screen.dart';
import 'package:ani_mobile/screens/downloads_screen.dart';
import 'package:ani_mobile/theme/app_theme.dart';
import 'package:ani_mobile/providers/scraper_provider.dart';
import 'package:ani_mobile/services/scraper/scraper_factory.dart';

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
}
