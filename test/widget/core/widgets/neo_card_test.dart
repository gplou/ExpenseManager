import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/widgets/neo_card.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  // ── NeoCard ─────────────────────────────────────────────────────────────

  group('NeoCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(wrap(
        const NeoCard(child: Text('hello')),
      ));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        NeoCard(
          onTap: () => taps++,
          child: const Text('tap me'),
        ),
      ));
      await tester.tap(find.text('tap me'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  // ── NeoBrutalButton ─────────────────────────────────────────────────────

  group('NeoBrutalButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrap(
        NeoBrutalButton(label: 'Continuar', onTap: () {}),
      ));
      expect(find.text('Continuar'), findsOneWidget);
    });

    testWidgets('renders emoji when provided', (tester) async {
      await tester.pumpWidget(wrap(
        NeoBrutalButton(label: 'Go', onTap: () {}, emoji: '🚀'),
      ));
      expect(find.text('🚀'), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('renders progress indicator when isLoading is true',
        (tester) async {
      await tester.pumpWidget(wrap(
        NeoBrutalButton(label: 'X', onTap: () {}, isLoading: true),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('X'), findsNothing);
    });

    testWidgets('does not invoke onTap when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        NeoBrutalButton(label: 'X', onTap: () => taps++, disabled: true),
      ));
      await tester.tap(find.text('X'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('does not invoke onTap when loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        NeoBrutalButton(label: 'X', onTap: () => taps++, isLoading: true),
      ));
      // Tap on the centre of the button (where the spinner is). Use pump()
      // instead of pumpAndSettle() — the CircularProgressIndicator animates
      // indefinitely so the latter would time out.
      await tester.tap(find.byType(NeoBrutalButton));
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, 0);
    });

    testWidgets('invokes onTap when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        NeoBrutalButton(label: 'X', onTap: () => taps++),
      ));
      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  // ── NeoFab ──────────────────────────────────────────────────────────────

  group('NeoFab', () {
    testWidgets('renders the requested icon', (tester) async {
      await tester.pumpWidget(wrap(
        NeoFab(icon: Icons.add, onTap: () {}),
      ));
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('invokes onTap after the press-release animation',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        NeoFab(icon: Icons.add, onTap: () => taps++),
      ));
      await tester.tap(find.byType(NeoFab));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
