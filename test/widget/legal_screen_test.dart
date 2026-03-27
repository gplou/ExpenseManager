import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/settings/legal_screen.dart';

void main() {
  const testTitle = 'Privacy Policy';
  const testContent = 'This is the full text of the privacy policy document.';

  Widget buildSubject({String title = testTitle, String content = testContent}) {
    return MaterialApp(
      home: LegalScreen(title: title, content: content),
    );
  }

  group('LegalScreen', () {
    testWidgets('renders title in AppBar', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text(testTitle), findsOneWidget);
      // Title is inside an AppBar
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(testTitle)),
        findsOneWidget,
      );
    });

    testWidgets('renders content text', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text(testContent), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('content is scrollable via SingleChildScrollView', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
