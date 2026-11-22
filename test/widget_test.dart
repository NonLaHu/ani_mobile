import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_mobile/main.dart';
import 'package:ani_mobile/screens/details_screen.dart';
import 'package:ani_mobile/theme/app_theme.dart';

void main() {
  testWidgets('App renders Home Screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AniMobileApp(),
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

  testWidgets('DetailsScreen renders episode items cleanly without ListTile assertions', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(
          child: DetailsScreen(animeId: 'jujutsu-kaisen'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Episodes section and list tiles render without assertions
    expect(find.text('Episodes'), findsOneWidget);
    expect(find.textContaining('Episode 1:'), findsWidgets);
  });
}
