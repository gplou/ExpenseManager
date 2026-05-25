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
import 'package:expense_manager/l10n/app_localizations.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState();
}

class _FakeProSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => SubscriptionState(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        source: 'google_play',
      );
}

class _FakeLocaleNotifier extends LocaleNotifier {
  @override
  Future<Locale> build() async => const Locale('es');
}

class _FakeVoiceParser extends Fake implements VoiceTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(String transcription) async => null;
}

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
    testWidgets('renders a single + FAB with the open-menu semantic label',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_buildFab());
        await tester.pumpAndSettle();

        expect(find.byType(NeoFab), findsOneWidget);
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

      final fabSemantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((s) => s.properties.label == 'Abrir menú de acciones');
      expect(fabSemantics.properties.button, isTrue);
    });

    testWidgets('non-PRO user sees the same single FAB', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_buildFab(isPro: false));
        await tester.pumpAndSettle();

        expect(find.byType(NeoFab), findsOneWidget);
        expect(
          find.bySemanticsLabel('Abrir menú de acciones'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });
  });
}
