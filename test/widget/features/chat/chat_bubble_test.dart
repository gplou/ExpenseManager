import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/chat/domain/chat_message.dart';
import 'package:expense_manager/features/chat/presentation/widgets/chat_bubble.dart';

void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: brightness == Brightness.dark
            ? ThemeData.dark()
            : ThemeData.light(),
        home: Scaffold(body: child),
      );

  ChatMessage msg({required String content, required bool isUser}) =>
      ChatMessage(
        content: content,
        isUser: isUser,
        timestamp: DateTime(2026, 1, 1),
      );

  group('ChatBubble', () {
    testWidgets('renders user message right-aligned', (tester) async {
      await tester.pumpWidget(wrap(
        ChatBubble(message: msg(content: 'hi', isUser: true)),
      ));
      expect(find.text('hi'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('renders assistant message left-aligned', (tester) async {
      await tester.pumpWidget(wrap(
        ChatBubble(message: msg(content: 'response', isUser: false)),
      ));
      expect(find.text('response'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('renders in dark theme', (tester) async {
      await tester.pumpWidget(wrap(
        ChatBubble(message: msg(content: 'dark', isUser: false)),
        brightness: Brightness.dark,
      ));
      expect(find.text('dark'), findsOneWidget);
    });

    testWidgets('user bubble in dark theme', (tester) async {
      await tester.pumpWidget(wrap(
        ChatBubble(message: msg(content: 'u', isUser: true)),
        brightness: Brightness.dark,
      ));
      expect(find.text('u'), findsOneWidget);
    });
  });
}
