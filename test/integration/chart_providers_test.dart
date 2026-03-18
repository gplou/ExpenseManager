import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:productivity_app/features/charts/presentation/providers/chart_providers.dart';
import 'package:productivity_app/features/transactions/data/transactions_repository.dart';
import 'package:productivity_app/features/transactions/domain/transaction_model.dart';
import 'package:productivity_app/features/transactions/domain/transactions_repository_contract.dart';
import 'package:productivity_app/features/transactions/presentation/providers/transactions_provider.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeTransactionsRepo implements TransactionsRepositoryContract {
  List<TransactionModel> data = [];

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
  Future<TransactionModel> createTransaction(TransactionModel t) async => t;

  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) async => t;

  @override
  Future<void> deleteTransaction(String id) async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

TransactionModel _tx({
  required String id,
  required double amount,
  required TransactionType type,
  String category = 'Otros',
  String? subcategory,
}) =>
    TransactionModel(
      id: id,
      userId: 'user-1',
      amount: amount,
      type: type,
      category: category,
      subcategory: subcategory,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

ProviderContainer _makeContainer(_FakeTransactionsRepo repo) {
  return ProviderContainer(
    overrides: [
      transactionsRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── chartTypeFilterProvider ──────────────────────────────────────────────

  group('chartTypeFilterProvider', () {
    test('initial value is expense', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(chartTypeFilterProvider), TransactionType.expense);
    });

    test('can be switched to income', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(chartTypeFilterProvider.notifier).state =
          TransactionType.income;
      expect(container.read(chartTypeFilterProvider), TransactionType.income);
    });
  });

  // ── chartCategoryFilterProvider ──────────────────────────────────────────

  group('chartCategoryFilterProvider', () {
    test('initial value is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(chartCategoryFilterProvider), isNull);
    });

    test('can be set and cleared', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(chartCategoryFilterProvider.notifier).state = 'Comida';
      expect(container.read(chartCategoryFilterProvider), 'Comida');

      container.read(chartCategoryFilterProvider.notifier).state = null;
      expect(container.read(chartCategoryFilterProvider), isNull);
    });
  });

  // ── chartDistributionProvider ────────────────────────────────────────────

  group('chartDistributionProvider', () {
    test('groups expenses by category', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 50, type: TransactionType.expense, category: 'Comida'),
          _tx(id: '2', amount: 30, type: TransactionType.expense, category: 'Comida'),
          _tx(id: '3', amount: 20, type: TransactionType.expense, category: 'Transporte'),
        ];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final dist =
          await container.read(chartDistributionProvider.future);
      expect(dist['Comida'], 80.0);
      expect(dist['Transporte'], 20.0);
    });

    test('only includes transactions matching the selected type', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 100, type: TransactionType.income, category: 'Salario'),
          _tx(id: '2', amount: 50, type: TransactionType.expense, category: 'Comida'),
        ];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      // Default filter is expense
      final dist = await container.read(chartDistributionProvider.future);
      expect(dist.containsKey('Salario'), isFalse);
      expect(dist['Comida'], 50.0);
    });

    test('groups by subcategory when a category filter is active', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(
              id: '1',
              amount: 30,
              type: TransactionType.expense,
              category: 'Comida',
              subcategory: 'Restaurante'),
          _tx(
              id: '2',
              amount: 20,
              type: TransactionType.expense,
              category: 'Comida',
              subcategory: 'Supermercado'),
          _tx(
              id: '3',
              amount: 10,
              type: TransactionType.expense,
              category: 'Comida',
              subcategory: 'Restaurante'),
          // Different category — should be excluded
          _tx(id: '4', amount: 5, type: TransactionType.expense, category: 'Transporte'),
        ];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(chartCategoryFilterProvider.notifier).state = 'Comida';

      final dist = await container.read(chartDistributionProvider.future);
      expect(dist['Restaurante'], 40.0);
      expect(dist['Supermercado'], 20.0);
      expect(dist.containsKey('Transporte'), isFalse);
    });

    test('uses sentinel key for transactions without subcategory', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 25, type: TransactionType.expense, category: 'Comida'),
        ];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(chartCategoryFilterProvider.notifier).state = 'Comida';

      final dist = await container.read(chartDistributionProvider.future);
      expect(dist['\x00_no_sub'], 25.0);
    });

    test('returns empty map when no transactions', () async {
      final repo = _FakeTransactionsRepo();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final dist = await container.read(chartDistributionProvider.future);
      expect(dist, isEmpty);
    });
  });

  // ── chartFilteredTotalProvider ───────────────────────────────────────────

  group('chartFilteredTotalProvider', () {
    test('sums all expenses by default', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 50, type: TransactionType.expense),
          _tx(id: '2', amount: 30, type: TransactionType.expense),
          _tx(id: '3', amount: 100, type: TransactionType.income),
        ];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final total = await container.read(chartFilteredTotalProvider.future);
      expect(total, 80.0);
    });

    test('filters by category when category filter is set', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 50, type: TransactionType.expense, category: 'Comida'),
          _tx(id: '2', amount: 30, type: TransactionType.expense, category: 'Transporte'),
        ];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(chartCategoryFilterProvider.notifier).state = 'Comida';

      final total = await container.read(chartFilteredTotalProvider.future);
      expect(total, 50.0);
    });

    test('filters by subcategory when both filters are set', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(
              id: '1',
              amount: 30,
              type: TransactionType.expense,
              category: 'Comida',
              subcategory: 'Restaurante'),
          _tx(
              id: '2',
              amount: 20,
              type: TransactionType.expense,
              category: 'Comida',
              subcategory: 'Supermercado'),
        ];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      container.read(chartCategoryFilterProvider.notifier).state = 'Comida';
      container.read(chartSubcategoryFilterProvider.notifier).state =
          'Restaurante';

      final total = await container.read(chartFilteredTotalProvider.future);
      expect(total, 30.0);
    });

    test('returns 0 when no matching transactions', () async {
      final repo = _FakeTransactionsRepo()
        ..data = [
          _tx(id: '1', amount: 100, type: TransactionType.income),
        ];
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      // Default filter is expense, so no matches
      final total = await container.read(chartFilteredTotalProvider.future);
      expect(total, 0.0);
    });
  });
}
