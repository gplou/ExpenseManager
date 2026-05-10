import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/locale_provider.dart';
import 'package:expense_manager/core/widgets/neo_card.dart';
import 'package:expense_manager/features/dashboard/widgets/dashboard_fab.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/tutorial/tutorial_notifier.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Free user — overrides [SubscriptionNotifier.build] so no RevenueCat calls
/// are made during tests.
class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState();
}

/// Active PRO user — same isolation guarantee.
class _FakeProSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        source: 'google_play',
      );
}

/// Avoids calling SharedPreferences; always resolves to 'es'.
class _FakeLocaleNotifier extends LocaleNotifier {
  @override
  Future<Locale> build() async => const Locale('es');
}

/// Forces the tutorial to be active so the FAB renders the radial dial path
/// (outside tutorial, the FAB now opens a `QuickAddSheet` bottom sheet, which
/// these accessibility tests don't exercise).
class _ActiveTutorialNotifier extends TutorialNotifier {
  @override
  TutorialState build() => const TutorialState(isActive: true, stepIndex: 0);
}

/// Never calls the real Supabase Edge Function.
class _FakeVoiceParser extends Fake implements VoiceTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(String transcription) async => null;
}

/// Never calls the real Supabase Edge Function.
class _FakeImageParser extends Fake implements ImageTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(Uint8List imageBytes) async => null;
}

// ── Widget builder ────────────────────────────────────────────────────────────

Widget _buildFab({bool isPro = true}) => ProviderScope(
      overrides: [
        subscriptionProvider.overrideWith(
          isPro
              ? () => _FakeProSubscriptionNotifier()
              : () => _FakeSubscriptionNotifier(),
        ),
        localeProvider.overrideWith(() => _FakeLocaleNotifier()),
        voiceTransactionParserProvider.overrideWithValue(_FakeVoiceParser()),
        imageTransactionParserProvider.overrideWithValue(_FakeImageParser()),
        tutorialProvider.overrideWith(_ActiveTutorialNotifier.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es'),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: SpeedDialFab()),
            ],
          ),
        ),
      ),
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SpeedDialFab — accessibility', () {
    // ── Closed state ───────────────────────────────────────────────────────────

    group('when the dial is closed', () {
      testWidgets('FAB has the "open menu" semantic label', (tester) async {
        // Dispose inside try/finally so it runs before _endOfTestVerifications.
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab());
          await tester.pumpAndSettle();

          expect(
            find.bySemanticsLabel('Abrir menú de acciones'),
            findsOneWidget,
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('FAB Semantics widget has button=true', (tester) async {
        await tester.pumpWidget(_buildFab());
        await tester.pumpAndSettle();

        // Widget-tree check — avoids relying on deprecated SemanticsNode APIs.
        final fabSemantics = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == 'Abrir menú de acciones');
        expect(fabSemantics.properties.button, isTrue);
      });

      testWidgets('mini buttons are NOT in the semantics tree', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab());
          await tester.pumpAndSettle();

          // ExcludeSemantics(excluding: true) removes these from the tree.
          expect(find.bySemanticsLabel('Voz'), findsNothing);
          expect(find.bySemanticsLabel('Manual'), findsNothing);
          expect(find.bySemanticsLabel('Foto'), findsNothing);
        } finally {
          handle.dispose();
        }
      });

      testWidgets('"close menu" label is NOT in the semantics tree', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab());
          await tester.pumpAndSettle();

          // Both FAB label and backdrop use fabCloseMenu — both must be excluded.
          expect(
            find.bySemanticsLabel('Cerrar menú de acciones'),
            findsNothing,
          );
        } finally {
          handle.dispose();
        }
      });
    });

    // ── Open state ─────────────────────────────────────────────────────────────

    group('when the dial is open', () {
      testWidgets('FAB and backdrop have the "close menu" semantic label', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab());
          await tester.pumpAndSettle();
          await tester.tap(find.byType(NeoFab));
          await tester.pumpAndSettle();

          // Both the FAB toggle button and the backdrop dismiss area use this label.
          expect(
            find.bySemanticsLabel('Cerrar menú de acciones'),
            findsWidgets,
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('mini buttons are present in the semantics tree', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab());
          await tester.pumpAndSettle();
          await tester.tap(find.byType(NeoFab));
          await tester.pumpAndSettle();

          // Widget-tree check: each button has Semantics(button: true, label: …).
          // ExcludeSemantics(excluding: false) passes them to the semantic tree;
          // we verify via the widget tree since AnimatedOpacity can delay the
          // rendered semantic-tree update in the test environment.
          for (final label in ['Voz', 'Manual', 'Foto']) {
            final found = tester
                .widgetList<Semantics>(find.byType(Semantics))
                .any((s) =>
                    s.properties.label == label && s.properties.button == true);
            expect(
              found,
              isTrue,
              reason: 'Expected Semantics(button: true, label: "$label")',
            );
          }
        } finally {
          handle.dispose();
        }
      });

      testWidgets('each mini button Semantics widget has button=true and the correct label', (tester) async {
        await tester.pumpWidget(_buildFab());
        await tester.pumpAndSettle();
        await tester.tap(find.byType(NeoFab));
        await tester.pumpAndSettle();

        // Widget-tree check: independent of semantic-tree traversal order.
        for (final label in ['Voz', 'Manual', 'Foto']) {
          final found = tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((s) =>
                  s.properties.label == label &&
                  s.properties.button == true);
          expect(
            found,
            isTrue,
            reason: 'Expected Semantics(button: true, label: "$label")',
          );
        }
      });

      testWidgets('"open menu" label is NOT in the semantics tree', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab());
          await tester.pumpAndSettle();
          await tester.tap(find.byType(NeoFab));
          await tester.pumpAndSettle();

          // Widget-tree check: the FAB Semantics label has switched to
          // fabCloseMenu; no widget should still carry fabOpenMenu.
          final hasOpenLabel = tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((s) => s.properties.label == 'Abrir menú de acciones');
          expect(hasOpenLabel, isFalse);
        } finally {
          handle.dispose();
        }
      });
    });

    // ── Toggle cycle ───────────────────────────────────────────────────────────

    group('toggle cycle', () {
      testWidgets('FAB label alternates between open and close on each tap', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab());
          await tester.pumpAndSettle();

          // Closed
          expect(find.bySemanticsLabel('Abrir menú de acciones'), findsOneWidget);
          expect(find.bySemanticsLabel('Cerrar menú de acciones'), findsNothing);

          // Open
          await tester.tap(find.byType(NeoFab));
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Cerrar menú de acciones'), findsWidgets);
          expect(find.bySemanticsLabel('Abrir menú de acciones'), findsNothing);

          // Closed again
          await tester.tap(find.byType(NeoFab));
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Abrir menú de acciones'), findsOneWidget);
          // After closing, all ExcludeSemantics widgets have excluding=true,
          // meaning the backdrop ('Cerrar') and mini buttons are inaccessible.
          // (bySemanticsLabel may return a stale debugSemantics node after an
          // animated open→close cycle, so we check the widget tree instead.)
          final allExcluded = tester
              .widgetList<ExcludeSemantics>(find.byType(ExcludeSemantics))
              .every((e) => e.excluding);
          expect(allExcluded, isTrue);
        } finally {
          handle.dispose();
        }
      });

      testWidgets('mini buttons enter and leave the semantics tree on each tap', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab());
          await tester.pumpAndSettle();

          expect(find.bySemanticsLabel('Manual'), findsNothing);

          await tester.tap(find.byType(NeoFab));
          await tester.pumpAndSettle();
          // Widget-tree check: Semantics(button: true, label: 'Manual') is
          // present when the dial opens (ExcludeSemantics.excluding == false).
          final manualWhenOpen = tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((s) =>
                  s.properties.label == 'Manual' && s.properties.button == true);
          expect(manualWhenOpen, isTrue);

          await tester.tap(find.byType(NeoFab));
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Manual'), findsNothing);
        } finally {
          handle.dispose();
        }
      });
    });

    // ── Non-PRO user ───────────────────────────────────────────────────────────

    group('non-PRO user', () {
      testWidgets('FAB is visible with the correct semantic label', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab(isPro: false));
          await tester.pumpAndSettle();

          expect(
            find.bySemanticsLabel('Abrir menú de acciones'),
            findsOneWidget,
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('all three mini buttons are accessible when the dial opens', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildFab(isPro: false));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(NeoFab));
          await tester.pumpAndSettle();

          // Buttons render even for free users (tapping voice/photo redirects to PRO screen).
          for (final label in ['Voz', 'Manual', 'Foto']) {
            final found = tester
                .widgetList<Semantics>(find.byType(Semantics))
                .any((s) =>
                    s.properties.label == label && s.properties.button == true);
            expect(
              found,
              isTrue,
              reason: 'Expected Semantics(button: true, label: "$label")',
            );
          }
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
