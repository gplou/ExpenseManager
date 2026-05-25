import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/services/image_input_gateway.dart';
import 'package:expense_manager/core/services/voice_input_gateway.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

class _MockSubRepo extends Mock implements SubcategoriesRepository {}

class _FakeVoiceGateway extends Fake implements VoiceInputGateway {
  @override
  Future<void> stop() async {}
}

class _FakeImageGateway extends Fake implements ImageInputGateway {}

class _FakeVoiceParser extends Fake implements VoiceTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(String transcription) async => null;
}

class _FakeImageParser extends Fake implements ImageTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(Uint8List imageBytes) async => null;
}

Widget _wrap({TransactionModel? transaction}) {
  SharedPreferences.setMockInitialValues({});
  final repo = _MockSubRepo();
  when(() => repo.getForCategory(any(), any())).thenAnswer((_) async => []);

  return ProviderScope(
    overrides: [
      isProProvider.overrideWithValue(true), // hide ad banner
      subcategoriesRepositoryProvider.overrideWithValue(repo),
      voiceInputGatewayProvider.overrideWithValue(_FakeVoiceGateway()),
      imageInputGatewayProvider.overrideWithValue(_FakeImageGateway()),
      voiceTransactionParserProvider.overrideWithValue(_FakeVoiceParser()),
      imageTransactionParserProvider.overrideWithValue(_FakeImageParser()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: AddTransactionScreen(transaction: transaction),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
  });

  testWidgets('renders the type toggle, keypad and save area for a new entry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // The screen shows trending icons in the type toggle and a numeric keypad.
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    // Keypad keys (1-9 each appear exactly once).
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('renders the transaction amount when editing an existing one',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 42.5,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 3, 15),
        createdAt: DateTime(2026, 3, 15),
      ),
    ));
    await tester.pumpAndSettle();

    // The pre-populated amount shows on the display.
    expect(find.textContaining('42'), findsAtLeastNWidgets(1));
  });
}
