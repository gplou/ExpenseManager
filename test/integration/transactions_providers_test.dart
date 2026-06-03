import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

// ── Fakes / mocks ─────────────────────────────────────────────────────────────

class _FakeTransactionsRepo implements TransactionsRepositoryContract {
  List<TransactionModel> data = [];
  TransactionsSummary? summaryOverride;

  final List<TransactionModel> created = [];
  final List<TransactionModel> updated = [];
  final List<String> deleted = [];

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) async =>
      data;

  @override
  Future<TransactionsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    if (summaryOverride != null) return summaryOverride!;
    double income = 0;
    double expense = 0;
    for (final t in data) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return TransactionsSummary(income: income, expense: expense);
  }

  @override
  Future<TransactionModel> createTransaction(TransactionModel t) async {
    created.add(t);
    data.add(t);
    return t;
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) async {
    updated.add(t);
    return t;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    deleted.add(id);
    data.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> upsertTransaction(TransactionModel t) async {
    data.removeWhere((e) => e.id == t.id);
    data.add(t);
  }
}

class _MockRecurringRepo extends Mock
    implements RecurringTransactionsRepositoryContract {}

// ── Helpers ───────────────────────────────────────────────────────────────────

TransactionModel _tx({
  required String id,
  required double amount,
  required TransactionType type,
  String category = 'Otros',
}) =>
    TransactionModel(
      id: id,
      userId: 'user-1',
      amount: amount,
      type: type,
      category: category,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

ProviderContainer _makeContainer(
  _FakeTransactionsRepo txRepo, {
  _MockRecurringRepo? recurringRepo,
}) {
  return ProviderContainer(
    overrides: [
      isProProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => null),
      transactionsRepositoryProvider.overrideWith((ref) => txRepo),
      if (recurringRepo != null)
        recurringTransactionsRepositoryProvider
            .overrideWith((ref) => recurringRepo),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── effectiveDateRangeProvider ────────────────────────────────────────────

  group('effectiveDateRangeProvider', () {
    test('returns period range when no custom range is set', () {
      final container = ProviderContainer(
        overrides: [
          transactionsRepositoryProvider
              .overrideWith((ref) => _FakeTransactionsRepo()),
        ],
      );
      addTearDown(container.dispose);

      final range = container.read(effectiveDateRangeProvider);
      final periodRange = TransactionPeriod.month.dateRange;

      expect(range.from, periodRange.from);
      expect(range.to, periodRange.to);
    });

    test('returns custom range when one is set', () {
      final container = ProviderContainer(
        overrides: [
          transactionsRepositoryProvider
              .overrideWith((ref) => _FakeTransactionsRepo()),
        ],
      );
      addTearDown(container.dispose);

      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 31);
      container.read(customDateRangeProvider.notifier).state =
          DateTimeRange(start: start, end: end);

      final range = container.read(effectiveDateRangeProvider);
      expect(range.from, start);
      expect(range.to, end);
    });

    test('custom range takes precedence over selected period', () {
      final container = ProviderContainer(
        overrides: [
          transactionsRepositoryProvider
              .overrideWith((ref) => _FakeTransactionsRepo()),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedPeriodProvider.notifier).state =
          TransactionPeriod.year;

      final custom = DateTimeRange(
        start: DateTime(2024, 6, 1),
        end: DateTime(2024, 6, 30),
      );
      container.read(customDateRangeProvider.notifier).state = custom;

      final range = container.read(effectiveDateRangeProvider);
      expect(range.from, custom.start);
      expect(range.to, custom.end);
    });

    test('clearing custom range falls back to period range', () {
      final container = ProviderContainer(
        overrides: [
          transactionsRepositoryProvider
              .overrideWith((ref) => _FakeTransactionsRepo()),
        ],
      );
      addTearDown(container.dispose);

      final custom = DateTimeRange(
        start: DateTime(2024, 3, 1),
        end: DateTime(2024, 3, 31),
      );
      container.read(customDateRangeProvider.notifier).state = custom;
      container.read(customDateRangeProvider.notifier).state = null;

      final range = container.read(effectiveDateRangeProvider);
      final periodRange = TransactionPeriod.month.dateRange;
      expect(range.from, periodRange.from);
    });
  });

  // ── recentTransactionsProvider ────────────────────────────────────────────

  group('recentTransactionsProvider', () {
    test('returns at most 3 transactions', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 10, type: TransactionType.expense),
          _tx(id: '2', amount: 20, type: TransactionType.income),
          _tx(id: '3', amount: 30, type: TransactionType.expense),
          _tx(id: '4', amount: 40, type: TransactionType.income),
          _tx(id: '5', amount: 50, type: TransactionType.expense),
        ];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final transactions = await container.read(recentTransactionsProvider.future);
      expect(transactions.length, 3);
    });

    test('returns all transactions when fewer than 3', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 10, type: TransactionType.expense),
          _tx(id: '2', amount: 20, type: TransactionType.income),
        ];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final transactions = await container.read(recentTransactionsProvider.future);
      expect(transactions.length, 2);
    });

    test('returns empty list when no transactions', () async {
      final repo = _FakeTransactionsRepo();

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final transactions = await container.read(recentTransactionsProvider.future);
      expect(transactions, isEmpty);
    });

    test('returns exactly the first 3 in order', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: 'a', amount: 100, type: TransactionType.income),
          _tx(id: 'b', amount: 200, type: TransactionType.expense),
          _tx(id: 'c', amount: 300, type: TransactionType.income),
          _tx(id: 'd', amount: 400, type: TransactionType.expense),
        ];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final transactions = await container.read(recentTransactionsProvider.future);
      expect(transactions.map((t) => t.id).toList(), ['a', 'b', 'c']);
    });
  });

  // ── categoryDistributionProvider ──────────────────────────────────────────

  group('categoryDistributionProvider', () {
    test('groups expense amounts by category', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 50, type: TransactionType.expense, category: 'Comida'),
          _tx(id: '2', amount: 30, type: TransactionType.expense, category: 'Comida'),
          _tx(id: '3', amount: 20, type: TransactionType.expense, category: 'Transporte'),
        ];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final dist = await container
          .read(categoryDistributionProvider(TransactionType.expense).future);

      expect(dist['Comida'], 80.0);
      expect(dist['Transporte'], 20.0);
    });

    test('only includes transactions of the requested type', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 100, type: TransactionType.income, category: 'Salario'),
          _tx(id: '2', amount: 50, type: TransactionType.expense, category: 'Comida'),
        ];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final incomeDist = await container
          .read(categoryDistributionProvider(TransactionType.income).future);
      expect(incomeDist.containsKey('Comida'), isFalse);
      expect(incomeDist['Salario'], 100.0);

      final expenseDist = await container
          .read(categoryDistributionProvider(TransactionType.expense).future);
      expect(expenseDist.containsKey('Salario'), isFalse);
      expect(expenseDist['Comida'], 50.0);
    });

    test('returns empty map when no transactions of that type', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 100, type: TransactionType.income, category: 'Salario'),
        ];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final dist = await container
          .read(categoryDistributionProvider(TransactionType.expense).future);
      expect(dist, isEmpty);
    });
  });

  // ── TransactionsNotifier ──────────────────────────────────────────────────

  group('TransactionsNotifier.create', () {
    test('calls repository createTransaction', () async {
      final repo = _FakeTransactionsRepo();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final tx = _tx(id: 'new-1', amount: 100, type: TransactionType.income);
      await container.read(transactionsNotifierProvider.notifier).create(tx);

      expect(repo.created, contains(tx));
    });
  });

  group('TransactionsNotifier.update', () {
    test('calls repository updateTransaction', () async {
      final repo = _FakeTransactionsRepo();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final tx = _tx(id: 'upd-1', amount: 200, type: TransactionType.expense);
      await container.read(transactionsNotifierProvider.notifier).update(tx);

      expect(repo.updated, contains(tx));
    });
  });

  group('TransactionsNotifier.delete', () {
    test('calls repository deleteTransaction without recurring', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [_tx(id: 'del-1', amount: 50, type: TransactionType.expense)];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(transactionsNotifierProvider.notifier)
          .delete('del-1');

      expect(repo.deleted, contains('del-1'));
    });

    test('also deletes recurring when recurringTransactionId provided', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [_tx(id: 'del-2', amount: 50, type: TransactionType.expense)];
      final recurringRepo = _MockRecurringRepo();
      when(() => recurringRepo.deleteRecurring(any()))
          .thenAnswer((_) async {});

      final container = _makeContainer(repo, recurringRepo: recurringRepo);
      addTearDown(container.dispose);

      await container
          .read(transactionsNotifierProvider.notifier)
          .delete('del-2', recurringTransactionId: 'rec-1');

      expect(repo.deleted, contains('del-2'));
      verify(() => recurringRepo.deleteRecurring('rec-1')).called(1);
    });

    test('does NOT call recurring repo when recurringTransactionId is null',
        () async {
      final repo = _FakeTransactionsRepo()
        ..data = [_tx(id: 'del-3', amount: 50, type: TransactionType.expense)];
      final recurringRepo = _MockRecurringRepo();

      final container = _makeContainer(repo, recurringRepo: recurringRepo);
      addTearDown(container.dispose);

      await container
          .read(transactionsNotifierProvider.notifier)
          .delete('del-3');

      verifyNever(() => recurringRepo.deleteRecurring(any()));
    });
  });

  // ── TransactionsNotifier.saveWithRecurrence ────────────────────────────────

  group('TransactionsNotifier.saveWithRecurrence', () {
    setUpAll(() {
      registerFallbackValue(RecurrenceType.monthly);
      registerFallbackValue(DateTime(2024));
      registerFallbackValue(TransactionType.expense);
    });

    // Fixed clock so nextRecurrenceDate and createdAt are deterministic.
    final fixedNow = DateTime(2024, 1, 15);

    TransactionModel txInput({
      String id = '',
      String? recurringTransactionId,
      double amount = 100,
      String category = 'Comida',
    }) =>
        TransactionModel(
          id: id,
          userId: id.isEmpty ? '' : 'user-1',
          amount: amount,
          type: TransactionType.expense,
          category: category,
          subcategory: 'Restaurante',
          description: 'cena',
          date: DateTime(2024, 1, 15),
          createdAt: fixedNow,
          recurringTransactionId: recurringTransactionId,
        );

    // ── Branch 1: new + non-recurring → only create ──────────────────────────
    test('new + non-recurring: creates tx without recurring schedule',
        () async {
      final repo = _FakeTransactionsRepo();
      final recurringRepo = _MockRecurringRepo();
      final container = _makeContainer(repo, recurringRepo: recurringRepo);
      addTearDown(container.dispose);

      await withClock(Clock.fixed(fixedNow), () async {
        await container
            .read(transactionsNotifierProvider.notifier)
            .saveWithRecurrence(
              transaction: txInput(),
              isEditing: false,
              isRecurring: false,
              recurrenceType: null,
              currency: 'USD',
            );
      });

      expect(repo.created, hasLength(1));
      expect(repo.created.single.recurringTransactionId, isNull);
      expect(repo.created.single.currency, 'USD');
      expect(repo.created.single.category, 'Comida');
      // copyWith preserves subcategory/description from the input.
      expect(repo.created.single.subcategory, 'Restaurante');
      expect(repo.created.single.description, 'cena');
      verifyZeroInteractions(recurringRepo);
    });

    // ── Branch 2: new + recurring → createRecurring + create with link ───────
    test('new + recurring: creates schedule then links it to the tx',
        () async {
      final repo = _FakeTransactionsRepo();
      final recurringRepo = _MockRecurringRepo();
      when(() => recurringRepo.createRecurring(
            amount: any(named: 'amount'),
            type: any(named: 'type'),
            category: any(named: 'category'),
            subcategory: any(named: 'subcategory'),
            description: any(named: 'description'),
            recurrenceType: any(named: 'recurrenceType'),
            nextOccurrence: any(named: 'nextOccurrence'),
          )).thenAnswer((_) async => 'rec-new');

      final container = _makeContainer(repo, recurringRepo: recurringRepo);
      addTearDown(container.dispose);

      await withClock(Clock.fixed(fixedNow), () async {
        await container
            .read(transactionsNotifierProvider.notifier)
            .saveWithRecurrence(
              transaction: txInput(),
              isEditing: false,
              isRecurring: true,
              recurrenceType: RecurrenceType.monthly,
              currency: 'EUR',
            );
      });

      verify(() => recurringRepo.createRecurring(
            amount: 100,
            type: TransactionType.expense,
            category: 'Comida',
            subcategory: 'Restaurante',
            description: 'cena',
            recurrenceType: RecurrenceType.monthly,
            nextOccurrence: nextRecurrenceDate(
                DateTime(2024, 1, 15), RecurrenceType.monthly),
          )).called(1);
      expect(repo.created, hasLength(1));
      expect(repo.created.single.recurringTransactionId, 'rec-new');
    });

    // ── Branch 3: edit + recurring + no existing schedule ────────────────────
    test('edit + recurring + no existing schedule: creates schedule + update',
        () async {
      final repo = _FakeTransactionsRepo();
      final recurringRepo = _MockRecurringRepo();
      when(() => recurringRepo.createRecurring(
            amount: any(named: 'amount'),
            type: any(named: 'type'),
            category: any(named: 'category'),
            subcategory: any(named: 'subcategory'),
            description: any(named: 'description'),
            recurrenceType: any(named: 'recurrenceType'),
            nextOccurrence: any(named: 'nextOccurrence'),
          )).thenAnswer((_) async => 'rec-created');

      final container = _makeContainer(repo, recurringRepo: recurringRepo);
      addTearDown(container.dispose);

      await container
          .read(transactionsNotifierProvider.notifier)
          .saveWithRecurrence(
            transaction: txInput(id: 'tx-1'),
            isEditing: true,
            isRecurring: true,
            recurrenceType: RecurrenceType.weekly,
            currency: 'EUR',
          );

      verify(() => recurringRepo.createRecurring(
            amount: any(named: 'amount'),
            type: any(named: 'type'),
            category: any(named: 'category'),
            subcategory: any(named: 'subcategory'),
            description: any(named: 'description'),
            recurrenceType: RecurrenceType.weekly,
            nextOccurrence: any(named: 'nextOccurrence'),
          )).called(1);
      expect(repo.updated, hasLength(1));
      expect(repo.updated.single.recurringTransactionId, 'rec-created');
    });

    // ── Branch 4: edit + recurring + existing schedule → update both ─────────
    test('edit + recurring + existing schedule: updates schedule + update',
        () async {
      final repo = _FakeTransactionsRepo();
      final recurringRepo = _MockRecurringRepo();
      when(() => recurringRepo.updateRecurring(
            id: any(named: 'id'),
            amount: any(named: 'amount'),
            type: any(named: 'type'),
            category: any(named: 'category'),
            subcategory: any(named: 'subcategory'),
            description: any(named: 'description'),
            recurrenceType: any(named: 'recurrenceType'),
            nextOccurrence: any(named: 'nextOccurrence'),
          )).thenAnswer((_) async {});

      final container = _makeContainer(repo, recurringRepo: recurringRepo);
      addTearDown(container.dispose);

      await container
          .read(transactionsNotifierProvider.notifier)
          .saveWithRecurrence(
            transaction:
                txInput(id: 'tx-2', recurringTransactionId: 'rec-existing'),
            isEditing: true,
            isRecurring: true,
            recurrenceType: RecurrenceType.monthly,
            currency: 'EUR',
          );

      verify(() => recurringRepo.updateRecurring(
            id: 'rec-existing',
            amount: any(named: 'amount'),
            type: any(named: 'type'),
            category: any(named: 'category'),
            subcategory: any(named: 'subcategory'),
            description: any(named: 'description'),
            recurrenceType: RecurrenceType.monthly,
            nextOccurrence: any(named: 'nextOccurrence'),
          )).called(1);
      // createRecurring was never stubbed; if it had been called the mock
      // would have thrown, so reaching here proves the update branch was taken.
      expect(repo.updated, hasLength(1));
      expect(repo.updated.single.recurringTransactionId, 'rec-existing');
    });

    // ── Branch 5: edit + non-recurring + existing schedule → delete schedule ─
    test('edit + non-recurring + existing schedule: deletes schedule + detach',
        () async {
      final repo = _FakeTransactionsRepo();
      final recurringRepo = _MockRecurringRepo();
      when(() => recurringRepo.deleteRecurring(any()))
          .thenAnswer((_) async {});

      final container = _makeContainer(repo, recurringRepo: recurringRepo);
      addTearDown(container.dispose);

      await container
          .read(transactionsNotifierProvider.notifier)
          .saveWithRecurrence(
            transaction:
                txInput(id: 'tx-3', recurringTransactionId: 'rec-old'),
            isEditing: true,
            isRecurring: false,
            recurrenceType: null,
            currency: 'EUR',
          );

      verify(() => recurringRepo.deleteRecurring('rec-old')).called(1);
      expect(repo.updated, hasLength(1));
      expect(repo.updated.single.recurringTransactionId, isNull);
    });

    // ── Branch 6: edit + non-recurring + no existing schedule → just update ──
    test('edit + non-recurring + no existing schedule: only detaches', () async {
      final repo = _FakeTransactionsRepo();
      final recurringRepo = _MockRecurringRepo();

      final container = _makeContainer(repo, recurringRepo: recurringRepo);
      addTearDown(container.dispose);

      await container
          .read(transactionsNotifierProvider.notifier)
          .saveWithRecurrence(
            transaction: txInput(id: 'tx-4'),
            isEditing: true,
            isRecurring: false,
            recurrenceType: null,
            currency: 'EUR',
          );

      verifyZeroInteractions(recurringRepo);
      expect(repo.updated, hasLength(1));
      expect(repo.updated.single.recurringTransactionId, isNull);
    });
  });
}
