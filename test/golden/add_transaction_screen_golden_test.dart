@Tags(['golden'])
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/services/image_input_gateway.dart';
import 'package:expense_manager/core/services/voice_input_gateway.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/recent_categories_strip.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Golden coverage for the Nocturne restyle. Baselines were generated on
/// macOS with the bundled Inter font — see test/README.md for why these are
/// excluded from the default `flutter test` run in CI.

class _MockTransactionsRepo extends Mock
    implements TransactionsRepositoryContract {}

class _MockRecurringRepo extends Mock
    implements RecurringTransactionsRepositoryContract {}

class _MockSubRepo extends Mock implements SubcategoriesRepository {}

class _FakeVoiceGateway extends Fake implements VoiceInputGateway {}

class _FakeImageGateway extends Fake implements ImageInputGateway {}

class _FakeVoiceParser extends Fake implements VoiceTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(
    String transcription, {
    List<Map<String, String>> subcategories = const [],
  }) async =>
      null;
}

class _FakeImageParser extends Fake implements ImageTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(
    Uint8List imageBytes, {
    List<Map<String, String>> subcategories = const [],
  }) async =>
      null;
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  Future<String> build() async => 'EUR';
}

void main() {
  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
  });

  Future<void> pumpAddTransaction(WidgetTester tester, ThemeData theme) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final subRepo = _MockSubRepo();
    when(() => subRepo.getForCategory(any(), any()))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isProProvider.overrideWithValue(true),
          subcategoriesRepositoryProvider.overrideWithValue(subRepo),
          voiceInputGatewayProvider.overrideWithValue(_FakeVoiceGateway()),
          imageInputGatewayProvider.overrideWithValue(_FakeImageGateway()),
          voiceTransactionParserProvider.overrideWithValue(_FakeVoiceParser()),
          imageTransactionParserProvider.overrideWithValue(_FakeImageParser()),
          transactionsRepositoryProvider
              .overrideWithValue(_MockTransactionsRepo()),
          recurringTransactionsRepositoryProvider
              .overrideWithValue(_MockRecurringRepo()),
          currencyProvider.overrideWith(_FakeCurrencyNotifier.new),
          customCategoriesSyncProvider.overrideWith(
            (ref) => <TransactionType, List<TransactionCategory>>{
              TransactionType.income: [],
              TransactionType.expense: [],
            },
          ),
          for (final type in TransactionType.values)
            quickCategoriesProvider(type).overrideWith(
              (_) async =>
                  type.isIncome ? const <String>[] : const ['Comida', 'Transporte'],
            ),
        ],
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: const AddTransactionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AddTransaction — light', (tester) async {
    await pumpAddTransaction(tester, AppTheme.lightTheme);
    await expectLater(
      find.byType(AddTransactionScreen),
      matchesGoldenFile('goldens/add_transaction_light.png'),
    );
  });

  testWidgets('AddTransaction — dark', (tester) async {
    await pumpAddTransaction(tester, AppTheme.darkTheme);
    await expectLater(
      find.byType(AddTransactionScreen),
      matchesGoldenFile('goldens/add_transaction_dark.png'),
    );
  });
}
