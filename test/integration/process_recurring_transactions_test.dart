import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/presentation/providers/recurring_transactions_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockRecurringRepo extends Mock
    implements RecurringTransactionsRepositoryContract {}

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

  @override
  Future<void> upsertTransaction(TransactionModel t) async {}
}

class _TrackingTxRepo implements TransactionsRepositoryContract {
  _TrackingTxRepo(this._inner, this._log);
  final _FakeTxRepo _inner;
  final List<String> _log;

  @override
  Future<TransactionModel> createTransaction(TransactionModel t) async {
    _log.add('create');
    return _inner.createTransaction(t);
  }

  @override
  Future<List<TransactionModel>> getTransactions({required DateTime from, required DateTime to}) =>
      _inner.getTransactions(from: from, to: to);
  @override
  Future<TransactionsSummary> getSummary({required DateTime from, required DateTime to}) =>
      _inner.getSummary(from: from, to: to);
  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) => _inner.updateTransaction(t);
  @override
  Future<void> deleteTransaction(String id) => _inner.deleteTransaction(id);
  @override
  Future<void> upsertTransaction(TransactionModel t) => _inner.upsertTransaction(t);
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
    resetProcessedRecurringState();
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

    test('advances nextOccurrence to the correct next date', () async {
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

    test('advances nextOccurrence BEFORE creating transaction — prevents duplicates on crash', () async {
      final callOrder = <String>[];

      when(() => recurringRepo.getDueRecurring())
          .thenAnswer((_) async => [_recurring(id: 'rec-1')]);
      when(() => recurringRepo.updateNextOccurrence(any(), any())).thenAnswer((_) async {
        callOrder.add('advance');
      });

      final trackingTxRepo = _TrackingTxRepo(txRepo, callOrder);
      final container = ProviderContainer(
        overrides: [
          recurringTransactionsRepositoryProvider
              .overrideWith((ref) => recurringRepo),
          transactionsRepositoryProvider.overrideWith((ref) => trackingTxRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(processRecurringTransactionsProvider.future);

      expect(
        callOrder,
        ['advance', 'create'],
        reason: 'nextOccurrence must be advanced before the transaction is '
            'created so that a crash between the two steps cannot cause '
            'duplicate transactions on the next session.',
      );
    });

    test('second concurrent run is a no-op (prevents duplicate cloud writes)', () async {
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [
            _recurring(id: 'rec-1'),
          ]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      final container = _makeContainer(
        recurringRepo: recurringRepo,
        txRepo: txRepo,
      );
      addTearDown(container.dispose);

      // Start first run.
      final first = container.read(processRecurringTransactionsProvider.future);

      // Invalidate (simulates pull-to-refresh) and start second run concurrently.
      container.invalidate(processRecurringTransactionsProvider);
      final second = container.read(processRecurringTransactionsProvider.future);

      await Future.wait([first, second]);

      // Despite two runs, each recurring transaction is only created once.
      expect(
        txRepo.created.length,
        1,
        reason: 'Concurrent invalidation must not cause duplicate transactions.',
      );
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
