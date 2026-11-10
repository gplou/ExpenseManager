import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/chat/domain/chat_message.dart';
import 'package:expense_manager/features/chat/presentation/widgets/chat_bubble.dart';

import '../../../helpers/pump_app.dart';

void main() {
  ThemeData themeFor(Brightness brightness) =>
      brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

  ChatMessage msg({required String content, required bool isUser}) =>
      ChatMessage(
        content: content,
        isUser: isUser,
        timestamp: DateTime(2026, 1, 1),
      );

  group('ChatBubble', () {
    testWidgets('renders user message right-aligned', (tester) async {
      await pumpWithProviders(
        tester,
        ChatBubble(message: msg(content: 'hi', isUser: true)),
      );
      expect(find.text('hi'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('renders assistant message left-aligned', (tester) async {
      await pumpWithProviders(
        tester,
        ChatBubble(message: msg(content: 'response', isUser: false)),
      );
      expect(find.text('response'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, Alignment.centerLeft);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpWithProviders(
        tester,
        ChatBubble(message: msg(content: 'dark', isUser: false)),
        theme: themeFor(Brightness.dark),
      );
      expect(find.text('dark'), findsOneWidget);
    });

    testWidgets('user bubble in dark theme', (tester) async {
      await pumpWithProviders(
        tester,
        ChatBubble(message: msg(content: 'u', isUser: true)),
        theme: themeFor(Brightness.dark),
      );
      expect(find.text('u'), findsOneWidget);
    });
  });

  group('RevealText', () {
    String visiblePart(WidgetTester tester) {
      final text = tester.widget<Text>(
        find.descendant(of: find.byType(RevealText), matching: find.byType(Text)),
      );
      if (text.textSpan == null) return text.data!;
      return (text.textSpan! as TextSpan).children!.first.toPlainText();
    }

    testWidgets('revela palabra a palabra y termina mostrando todo',
        (tester) async {
      const content = 'Este mes tu mayor gasto es Vivienda';
      await pumpWithProviders(
        tester,
        ChatBubble(
          message: msg(content: content, isUser: false),
          animate: true,
        ),
      );
      expect(visiblePart(tester), isNot(content));

      await tester.pump(RevealText.durationFor(content) ~/ 2);
      final partial = visiblePart(tester);
      expect(partial, isNotEmpty);
      expect(content.startsWith(partial), isTrue);
      expect(partial.length, lessThan(content.length));

      await tester.pumpAndSettle();
      expect(visiblePart(tester), content);
      // El texto completo es localizable durante y después de la animación.
      expect(find.text(content), findsOneWidget);
    });

    testWidgets('un toque muestra el mensaje entero al instante',
        (tester) async {
      const content = 'Respuesta bastante larga para que tarde en revelarse';
      await pumpWithProviders(
        tester,
        ChatBubble(
          message: msg(content: content, isUser: false),
          animate: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(RevealText));
      await tester.pump();
      expect(visiblePart(tester), content);
    });

    testWidgets('sin animate se muestra entero desde el primer frame',
        (tester) async {
      await pumpWithProviders(
        tester,
        ChatBubble(message: msg(content: 'hola qué tal', isUser: false)),
      );
      expect(visiblePart(tester), 'hola qué tal');
    });

    test('la duración escala con la longitud y tiene tope', () {
      expect(RevealText.durationFor('hola'),
          const Duration(milliseconds: 350));
      expect(RevealText.durationFor('a' * 1000),
          const Duration(milliseconds: 1600));
    });
  });
}
