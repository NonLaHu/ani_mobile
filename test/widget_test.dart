import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_mobile/main.dart';

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
}
