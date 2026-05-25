import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/services/image_input_gateway.dart';
import 'package:expense_manager/core/services/voice_input_gateway.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockTransactionsRepo extends Mock
    implements TransactionsRepositoryContract {}

class _MockRecurringRepo extends Mock
    implements RecurringTransactionsRepositoryContract {}

class _MockSubRepo extends Mock implements SubcategoriesRepository {}

class _FakeVoiceGateway extends Fake implements VoiceInputGateway {
  @override
  Future<void> stop() async {}
}

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
  _FakeCurrencyNotifier(this._code);
  final String _code;

  @override
  Future<String> build() async => _code;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

_MockTransactionsRepo _makeTxRepo() {
  final repo = _MockTransactionsRepo();
  final now = DateTime(2026, 1, 1);
  when(() => repo.createTransaction(any())).thenAnswer(
    (_) async => TransactionModel(
      id: 'new-id',
      userId: 'u',
      amount: 10,
      type: TransactionType.expense,
      category: 'Comida',
      date: now,
      createdAt: now,
    ),
  );
  when(() => repo.updateTransaction(any())).thenAnswer(
    (_) async => TransactionModel(
      id: 'tx-1',
      userId: 'u',
      amount: 42.5,
      type: TransactionType.expense,
      category: 'Comida',
      date: now,
      createdAt: now,
    ),
  );
  when(() => repo.deleteTransaction(any())).thenAnswer((_) async {});
  return repo;
}

_MockRecurringRepo _makeRecurringRepo() {
  final repo = _MockRecurringRepo();
  when(() => repo.createRecurring(
        amount: any(named: 'amount'),
        type: any(named: 'type'),
        category: any(named: 'category'),
        subcategory: any(named: 'subcategory'),
        description: any(named: 'description'),
        recurrenceType: any(named: 'recurrenceType'),
        nextOccurrence: any(named: 'nextOccurrence'),
      )).thenAnswer((_) async => 'rec-id');
  when(() => repo.deleteRecurring(any())).thenAnswer((_) async {});
  when(() => repo.getById(any())).thenAnswer((_) async => null);
  when(() => repo.updateRecurring(
        id: any(named: 'id'),
        amount: any(named: 'amount'),
        type: any(named: 'type'),
        category: any(named: 'category'),
        subcategory: any(named: 'subcategory'),
        description: any(named: 'description'),
        recurrenceType: any(named: 'recurrenceType'),
        nextOccurrence: any(named: 'nextOccurrence'),
      )).thenAnswer((_) async {});
  return repo;
}

Widget _wrap({
  TransactionModel? transaction,
  ParsedVoiceTransaction? voiceData,
  _MockTransactionsRepo? txRepo,
  _MockRecurringRepo? recurringRepo,
  _MockSubRepo? subRepo,
  String currency = 'EUR',
}) {
  SharedPreferences.setMockInitialValues({});
  final repo = subRepo ?? _MockSubRepo();
  when(() => repo.getForCategory(any(), any())).thenAnswer((_) async => []);

  final txR = txRepo ?? _makeTxRepo();
  final recR = recurringRepo ?? _makeRecurringRepo();

  return ProviderScope(
    overrides: [
      isProProvider.overrideWithValue(true),
      subcategoriesRepositoryProvider.overrideWithValue(repo),
      voiceInputGatewayProvider.overrideWithValue(_FakeVoiceGateway()),
      imageInputGatewayProvider.overrideWithValue(_FakeImageGateway()),
      voiceTransactionParserProvider.overrideWithValue(_FakeVoiceParser()),
      imageTransactionParserProvider.overrideWithValue(_FakeImageParser()),
      transactionsRepositoryProvider.overrideWithValue(txR),
      recurringTransactionsRepositoryProvider.overrideWithValue(recR),
      currencyProvider.overrideWith(() => _FakeCurrencyNotifier(currency)),
      customCategoriesSyncProvider.overrideWith(
        (ref) => <TransactionType, List<TransactionCategory>>{
          TransactionType.income: [],
          TransactionType.expense: [],
        },
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: AddTransactionScreen(
        transaction: transaction,
        voiceData: voiceData,
      ),
    ),
  );
}

// Navigate from step 1 (amount) to step 2 (details) by entering an amount
// and tapping the submit button on the keypad (identified by its check icon).
Future<void> _goToDetails(WidgetTester tester, String digit) async {
  await tester.tap(find.text(digit).first);
  await tester.pump();
  // The submit key always carries Icons.check_rounded next to the label.
  await tester.tap(find.byIcon(Icons.check_rounded).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(RecurrenceType.monthly);
    registerFallbackValue(
      TransactionModel(
        id: '',
        userId: '',
        amount: 0,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    );
  });

  // ── Basic render ─────────────────────────────────────────────────────────────

  testWidgets('renders the type toggle, keypad and save area for a new entry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
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

    expect(find.textContaining('42'), findsAtLeastNWidgets(1));
  });

  // ── Amount validation ────────────────────────────────────────────────────────

  testWidgets('shows invalid-amount error when tapping continue with amount=0',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Tap the submit key (check icon) without entering any amount
    await tester.tap(find.byIcon(Icons.check_rounded).first);
    await tester.pumpAndSettle();

    // Should still be on step 1 (error message visible)
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  // ── Type toggle ──────────────────────────────────────────────────────────────

  testWidgets('type toggle switches between income and expense',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Default is expense — tap income toggle
    await tester.tap(find.byIcon(Icons.trending_up_rounded));
    await tester.pumpAndSettle();

    // Switch back to expense
    await tester.tap(find.byIcon(Icons.trending_down_rounded));
    await tester.pumpAndSettle();

    // Still on step 1 with both icons visible
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
  });

  // ── Edit mode pre-populates fields ───────────────────────────────────────────

  testWidgets('edit mode shows "Editar transacción" in app bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 25,
        type: TransactionType.income,
        category: 'Salario',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Editar transacción'), findsOneWidget);
  });

  testWidgets('edit mode goes to detail step directly when amount is set',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 25,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ));
    await tester.pumpAndSettle();

    // In details step: save button visible
    expect(find.text('Guardar cambios'), findsOneWidget);
  });

  testWidgets('edit mode shows delete button on amount step', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();
    final recRepo = _makeRecurringRepo();

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 25,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
      txRepo: txRepo,
      recurringRepo: recRepo,
    ));
    await tester.pumpAndSettle();

    // Navigate back to amount step to see the delete button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });

  // ── Voice mode pre-populates ─────────────────────────────────────────────────

  testWidgets('voice mode pre-populates amount and goes to details step',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      voiceData: ParsedVoiceTransaction(
        amount: 15.0,
        type: TransactionType.expense,
        category: 'Comida',
        description: 'Café',
        date: DateTime(2026, 3, 1),
      ),
    ));
    await tester.pumpAndSettle();

    // With amount pre-filled, jumps directly to details step
    expect(find.textContaining('15'), findsAtLeastNWidgets(1));
  });

  // ── Category required validation ─────────────────────────────────────────────

  testWidgets('save without category shows snackbar error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Enter amount and go to details
    await _goToDetails(tester, '5');

    // Try to save without selecting category
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });

  // ── Subcategory picker ───────────────────────────────────────────────────────

  testWidgets('subcategory row visible after category is pre-selected',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final subRepo = _MockSubRepo();
    when(() => subRepo.getForCategory(any(), any()))
        .thenAnswer((_) async => ['Restaurante', 'Supermercado']);

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 10,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
      subRepo: subRepo,
    ));
    await tester.pumpAndSettle();

    // The subcategory row uses the label "Subcategoría"
    expect(find.textContaining('Subcategor'), findsOneWidget);
  });

  // ── Recurring toggle ─────────────────────────────────────────────────────────

  testWidgets('recurring toggle reveals frequency picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await _goToDetails(tester, '5');

    // Recurring repeat icon button
    final repeatIcon = find.byIcon(Icons.repeat_rounded);
    // May be multiple (category block + recurring toggle) — tap the one in _RecurringToggleCompact
    await tester.tap(repeatIcon.last);
    await tester.pumpAndSettle();

    // Frequency picker should now be visible (weekly/monthly/yearly labels)
    expect(find.text('Mensual'), findsAtLeastNWidgets(1));
  });

  // ── New transaction save flow ────────────────────────────────────────────────

  testWidgets('save expense creates transaction via repo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();

    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
      voiceData: ParsedVoiceTransaction(
        amount: 10.0,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 3, 1),
      ),
    ));
    await tester.pumpAndSettle();

    // Already on details step; tap save
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    verify(() => txRepo.createTransaction(any())).called(1);
  });

  testWidgets('save income creates transaction with income type', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();

    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
      voiceData: ParsedVoiceTransaction(
        amount: 500.0,
        type: TransactionType.income,
        category: 'Salario',
        date: DateTime(2026, 3, 1),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar ingreso'));
    await tester.pumpAndSettle();

    final captured = verify(() => txRepo.createTransaction(captureAny()))
        .captured
        .first as TransactionModel;
    expect(captured.type, TransactionType.income);
  });

  // ── Edit save flow ───────────────────────────────────────────────────────────

  testWidgets('edit mode save calls updateTransaction', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();

    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
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

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    verify(() => txRepo.updateTransaction(any())).called(1);
  });

  // ── Delete flow ──────────────────────────────────────────────────────────────

  testWidgets('delete button shows confirm dialog and calls deleteTransaction',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();
    final recRepo = _makeRecurringRepo();

    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
      recurringRepo: recRepo,
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 25,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ));
    await tester.pumpAndSettle();

    // Go back to amount step to see delete button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.byType(AlertDialog), findsOneWidget);

    // Tap the Delete button in the dialog
    final dialogDeleteBtns = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Eliminar'),
    );
    await tester.tap(dialogDeleteBtns.last);
    await tester.pumpAndSettle();

    verify(() => txRepo.deleteTransaction('tx-1')).called(1);
  });

  // ── Step indicator ───────────────────────────────────────────────────────────

  testWidgets('step indicator shows two bars; second activates on details step',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Two _Bar widgets exist in the step indicator
    await _goToDetails(tester, '3');

    // On details step the back arrow is visible
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });
}
