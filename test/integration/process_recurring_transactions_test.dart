import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:productivity_app/features/transactions/data/recurring_transactions_repository.dart';
import 'package:productivity_app/features/transactions/data/transactions_repository.dart';
import 'package:productivity_app/features/transactions/domain/recurring_transaction_model.dart';
import 'package:productivity_app/features/transactions/domain/transaction_model.dart';
import 'package:productivity_app/features/transactions/domain/transactions_repository_contract.dart';
import 'package:productivity_app/features/transactions/presentation/providers/recurring_transactions_provider.dart';
import 'package:productivity_app/features/transactions/presentation/providers/transactions_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockRecurringRepo extends Mock
    implements RecurringTransactionsRepository {}

class _FakeTxRepo implements TransactionsRepositoryContract {
  final List<TransactionModel> created = [];

  @override
  Future<TransactionModel> createTransaction(TransactionModel t) async {
    created.add(t);
    return t;
  }

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) async =>
      created;

  @override
  Future<TransactionsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async =>
      const TransactionsSummary(income: 0, expense: 0);

  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) async => t;

  @override
  Future<void> deleteTransaction(String id) async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

RecurringTransactionModel _recurring({
  String id = 'rec-1',
  double amount = 100.0,
  TransactionType type = TransactionType.expense,
  String category = 'Comida',
  RecurrenceType recurrenceType = RecurrenceType.monthly,
  DateTime? nextOccurrence,
}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'user-1',
      amount: amount,
      type: type,
      category: category,
      recurrenceType: recurrenceType,
      nextOccurrence: nextOccurrence ?? DateTime(2024, 1, 15),
      createdAt: DateTime(2024, 1, 1),
    );

ProviderContainer _makeContainer({
  required _MockRecurringRepo recurringRepo,
  required _FakeTxRepo txRepo,
}) {
  return ProviderContainer(
    overrides: [
      recurringTransactionsRepositoryProvider
          .overrideWith((ref) => recurringRepo),
      transactionsRepositoryProvider.overrideWith((ref) => txRepo),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockRecurringRepo recurringRepo;
  late _FakeTxRepo txRepo;

  setUp(() {
    recurringRepo = _MockRecurringRepo();
    txRepo = _FakeTxRepo();
    registerFallbackValue(
      TransactionModel(
        id: '',
        userId: '',
        amount: 0,
        type: TransactionType.expense,
        category: '',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
  });

  group('processRecurringTransactionsProvider', () {
    test('does nothing when no due recurring transactions', () async {
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => []);

      final container = _makeContainer(
        recurringRepo: recurringRepo,
        txRepo: txRepo,
      );
      addTearDown(container.dispose);

      await container.read(processRecurringTransactionsProvider.future);

      expect(txRepo.created, isEmpty);
      verifyNever(() => recurringRepo.updateNextOccurrence(any(), any()));
    });

    test('creates a transaction for each due recurring', () async {
      final r = _recurring(id: 'rec-1', amount: 50, category: 'Comida');
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      final container = _makeContainer(
        recurringRepo: recurringRepo,
        txRepo: txRepo,
      );
      addTearDown(container.dispose);

      await container.read(processRecurringTransactionsProvider.future);

      expect(txRepo.created.length, 1);
      final created = txRepo.created.first;
      expect(created.amount, 50.0);
      expect(created.category, 'Comida');
      expect(created.recurringTransactionId, 'rec-1');
    });

    test('uses nextOccurrence as the transaction date', () async {
      final dueDate = DateTime(2024, 3, 15);
      final r = _recurring(nextOccurrence: dueDate);
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      final container = _makeContainer(
        recurringRepo: recurringRepo,
        txRepo: txRepo,
      );
      addTearDown(container.dispose);

      await container.read(processRecurringTransactionsProvider.future);

      expect(txRepo.created.first.date, dueDate);
    });

    test('advances nextOccurrence after creating transaction', () async {
      final dueDate = DateTime(2024, 3, 15);
      final r = _recurring(
        id: 'rec-1',
        nextOccurrence: dueDate,
        recurrenceType: RecurrenceType.monthly,
      );
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      final container = _makeContainer(
        recurringRepo: recurringRepo,
        txRepo: txRepo,
      );
      addTearDown(container.dispose);

      await container.read(processRecurringTransactionsProvider.future);

      final captured = verify(() =>
              recurringRepo.updateNextOccurrence('rec-1', captureAny()))
          .captured;
      final nextDate = captured.first as DateTime;
      // Monthly: Mar 15 → Apr 15
      expect(nextDate, DateTime(2024, 4, 15));
    });

    test('processes multiple due recurring transactions', () async {
      final r1 = _recurring(id: 'rec-1', amount: 100, category: 'Comida');
      final r2 = _recurring(id: 'rec-2', amount: 200, category: 'Transporte');
      when(() => recurringRepo.getDueRecurring())
          .thenAnswer((_) async => [r1, r2]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      final container = _makeContainer(
        recurringRepo: recurringRepo,
        txRepo: txRepo,
      );
      addTearDown(container.dispose);

      await container.read(processRecurringTransactionsProvider.future);

      expect(txRepo.created.length, 2);
      expect(txRepo.created.map((t) => t.category).toList(),
          containsAll(['Comida', 'Transporte']));
      verify(() => recurringRepo.updateNextOccurrence(any(), any()))
          .called(2);
    });

    test('transaction type matches recurring type', () async {
      final r = _recurring(type: TransactionType.income, category: 'Salario');
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      final container = _makeContainer(
        recurringRepo: recurringRepo,
        txRepo: txRepo,
      );
      addTearDown(container.dispose);

      await container.read(processRecurringTransactionsProvider.future);

      expect(txRepo.created.first.type, TransactionType.income);
    });
  });
}
