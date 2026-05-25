import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/tutorial/tutorial_step.dart';
import 'package:expense_manager/features/tutorial/tutorial_tooltip_card.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

TutorialStep _step({String title = 'Título', String body = 'Cuerpo', IconData? icon}) =>
    TutorialStep(
      title: title,
      body: body,
      targetKey: GlobalKey(),
      icon: icon,
    );

Widget _wrapCard(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(
        body: Center(child: child),
      ),
    );

Widget _card({
  TutorialStep? step,
  int stepIndex = 0,
  int totalSteps = 3,
  bool isLast = false,
  bool isFirst = true,
  VoidCallback? onNext,
  VoidCallback? onBack,
}) =>
    _wrapCard(
      TutorialTooltipCard(
        step: step ?? _step(),
        stepIndex: stepIndex,
        totalSteps: totalSteps,
        isLast: isLast,
        isFirst: isFirst,
        onNext: onNext ?? () {},
        onBack: onBack ?? () {},
      ),
    );

// ── TutorialTooltipCard tests ─────────────────────────────────────────────────

void main() {
  group('TutorialTooltipCard', () {
    testWidgets('renders title and body text', (tester) async {
      await tester.pumpWidget(_card(
        step: _step(title: 'Mi título', body: 'Mi descripción'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mi título'), findsOneWidget);
      expect(find.text('Mi descripción'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(_card(
        step: _step(icon: Icons.star_rounded),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('does not render icon when null', (tester) async {
      await tester.pumpWidget(_card(
        step: _step(icon: null),
      ));
      await tester.pumpAndSettle();

      // No icon widget at all (back arrow and forward are the only icons)
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('back button is hidden on first step', (tester) async {
      await tester.pumpWidget(_card(isFirst: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('back button is visible on non-first step', (tester) async {
      await tester.pumpWidget(_card(isFirst: false, stepIndex: 1));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('next button shows "Siguiente" when not last step', (tester) async {
      await tester.pumpWidget(_card(isLast: false));
      await tester.pumpAndSettle();

      expect(find.text('Siguiente'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('next button shows "Finalizar" on last step', (tester) async {
      await tester.pumpWidget(_card(isLast: true));
      await tester.pumpAndSettle();

      expect(find.text('Finalizar'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('onNext is called when next button is tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(_card(onNext: () => called = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Siguiente'));
      expect(called, isTrue);
    });

    testWidgets('onBack is called when back button is tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(_card(
        isFirst: false,
        stepIndex: 1,
        onBack: () => called = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      expect(called, isTrue);
    });
  });

  // ── TutorialStepDots tests ────────────────────────────────────────────────────

  group('TutorialStepDots', () {
    Widget makeDots({
      required int totalSteps,
      required int stepIndex,
      bool isDark = false,
    }) =>
        _wrapCard(
          TutorialStepDots(
            totalSteps: totalSteps,
            stepIndex: stepIndex,
            isDark: isDark,
          ),
        );

    testWidgets('renders N dots for N steps when N <= maxVisible', (tester) async {
      await tester.pumpWidget(makeDots(totalSteps: 4, stepIndex: 0));
      await tester.pumpAndSettle();

      // Each dot is an AnimatedContainer inside a Row
      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(containers.length, 4);
    });

    testWidgets('renders only maxVisible dots when totalSteps > maxVisible',
        (tester) async {
      await tester.pumpWidget(makeDots(totalSteps: 8, stepIndex: 0));
      await tester.pumpAndSettle();

      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(containers.length, TutorialStepDots.maxVisible);
    });

    testWidgets('active dot is larger than inactive dots', (tester) async {
      await tester.pumpWidget(makeDots(totalSteps: 3, stepIndex: 1));
      await tester.pumpAndSettle();

      final containers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();

      // stepIndex=1 → second dot is active (size 10), others are 7
      final sizes = containers
          .map((c) => (c.constraints?.maxWidth ?? 0.0))
          .toList();

      // Active dot (index 1) should be bigger than its neighbors
      expect(sizes[1], greaterThan(sizes[0]));
      expect(sizes[1], greaterThan(sizes[2]));
    });

    testWidgets('renders with isDark=true without errors', (tester) async {
      await tester.pumpWidget(makeDots(totalSteps: 3, stepIndex: 0, isDark: true));
      await tester.pumpAndSettle();

      expect(find.byType(TutorialStepDots), findsOneWidget);
    });
  });

  // ── TutorialSpotlightPainter tests ───────────────────────────────────────────

  group('TutorialSpotlightPainter', () {
    testWidgets('CustomPaint with TutorialSpotlightPainter renders without error',
        (tester) async {
      const spotlight = Rect.fromLTWH(50, 100, 200, 80);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 800),
              painter: const TutorialSpotlightPainter(
                spotlightRect: spotlight,
                radius: 16,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    test('shouldRepaint returns false when rect and radius unchanged', () {
      const p1 = TutorialSpotlightPainter(
        spotlightRect: Rect.fromLTWH(0, 0, 100, 50),
        radius: 12,
      );
      const p2 = TutorialSpotlightPainter(
        spotlightRect: Rect.fromLTWH(0, 0, 100, 50),
        radius: 12,
      );
      expect(p1.shouldRepaint(p2), isFalse);
    });

    test('shouldRepaint returns true when rect changes', () {
      const p1 = TutorialSpotlightPainter(
        spotlightRect: Rect.fromLTWH(0, 0, 100, 50),
        radius: 12,
      );
      const p2 = TutorialSpotlightPainter(
        spotlightRect: Rect.fromLTWH(10, 0, 100, 50),
        radius: 12,
      );
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('shouldRepaint returns true when radius changes', () {
      const p1 = TutorialSpotlightPainter(
        spotlightRect: Rect.fromLTWH(0, 0, 100, 50),
        radius: 12,
      );
      const p2 = TutorialSpotlightPainter(
        spotlightRect: Rect.fromLTWH(0, 0, 100, 50),
        radius: 20,
      );
      expect(p1.shouldRepaint(p2), isTrue);
    });
  });
}
