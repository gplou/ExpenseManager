import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/budgets/data/budgets_repository.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/budgets/domain/budgets_repository_contract.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

import '../../helpers/mocks.dart';
import '../../helpers/provider_container_helper.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeBudgetsRepo implements BudgetsRepositoryContract {
  _FakeBudgetsRepo([List<BudgetModel>? seed]) : store = [...?seed];

  final List<BudgetModel> store;
  int _seq = 0;

  @override
  Future<List<BudgetModel>> getBudgets() async => [...store];

  @override
  Future<BudgetModel> createBudget(BudgetModel budget) async {
    final created = budget.copyWith(id: 'b${++_seq}', userId: 'u1');
    store.add(created);
    return created;
  }

  @override
  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    final i = store.indexWhere((b) => b.id == budget.id);
    store[i] = budget;
    return budget;
  }

  @override
  Future<void> deleteBudget(String id) async {
    store.removeWhere((b) => b.id == id);
  }
}

class _FakeCurrency extends CurrencyNotifier {
  @override
  Future<String> build() async => 'USD';
}

class _FakeAllTransactions extends AllTransactionsNotifier {
  @override
  Future<List<TransactionModel>> build() async => const [];
}

final _fakeUser = UserModel(
  id: 'u1',
  email: 'u1@test.com',
  createdAt: DateTime(2024, 1, 1),
);

BudgetModel _budget({
  String id = 'b0',
  String category = 'Comida',
  double amount = 100,
}) =>
    BudgetModel(
      id: id,
      userId: 'u1',
      category: category,
      amount: amount,
      createdAt: DateTime(2026, 6, 1),
    );

TransactionModel _tx({
  required String id,
  String category = 'Comida',
  double amount = 10,
  TransactionType type = TransactionType.expense,
}) =>
    TransactionModel(
      id: id,
      userId: 'u1',
      amount: amount,
      type: type,
      category: category,
      date: DateTime(2026, 6, 10),
      createdAt: DateTime(2026, 6, 10),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCommonFallbacks);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeBudgetsContainer({
    required _FakeBudgetsRepo repo,
    bool isPro = false,
  }) {
    return makeContainer([
      currentUserProvider.overrideWith((ref) => _fakeUser),
      isProProvider.overrideWith((ref) => isPro),
      budgetsRepositoryProvider.overrideWith((ref) => repo),
      currencyProvider.overrideWith(_FakeCurrency.new),
    ]);
  }

  group('BudgetsNotifier', () {
    test('build loads budgets from the repository', () async {
      final container = makeBudgetsContainer(
        repo: _FakeBudgetsRepo([_budget()]),
      );
      final budgets = await container.read(budgetsProvider.future);
      expect(budgets.single.category, 'Comida');
    });

    test('FREE user hits the limit with $kFreeBudgetLimit budget', () async {
      final container = makeBudgetsContainer(
        repo: _FakeBudgetsRepo([_budget()]),
      );
      await container.read(budgetsProvider.future);

      expect(
        () => container
            .read(budgetsProvider.notifier)
            .create(category: 'Ocio', amount: 50),
        throwsA(isA<FreeLimitFailure>()),
      );
    });

    test('PRO user can create beyond the FREE limit, sorted and with the '
        'global currency stamped', () async {
      final repo = _FakeBudgetsRepo([_budget(category: 'Transporte')]);
      final container = makeBudgetsContainer(repo: repo, isPro: true);
      await container.read(budgetsProvider.future);

      await container
          .read(budgetsProvider.notifier)
          .create(category: 'Comida', amount: 50);

      final budgets = container.read(budgetsProvider).value!;
      expect(budgets.map((b) => b.category), ['Comida', 'Transporte']);
      expect(repo.store.last.currency, 'USD');
    });

    test('rejects a duplicate category with ValidationFailure', () async {
      final container = makeBudgetsContainer(
        repo: _FakeBudgetsRepo([_budget(category: 'Comida')]),
        isPro: true,
      );
      await container.read(budgetsProvider.future);

      expect(
        () => container
            .read(budgetsProvider.notifier)
            .create(category: 'Comida', amount: 50),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('updateBudget and deleteBudget update the state', () async {
      final container = makeBudgetsContainer(
        repo: _FakeBudgetsRepo([_budget(id: 'b1', amount: 100)]),
        isPro: true,
      );
      final initial = await container.read(budgetsProvider.future);

      await container
          .read(budgetsProvider.notifier)
          .updateBudget(initial.single.copyWith(amount: 300));
      expect(container.read(budgetsProvider).value!.single.amount, 300);

      await container.read(budgetsProvider.notifier).deleteBudget('b1');
      expect(container.read(budgetsProvider).value, isEmpty);
    });
  });

  group('budgetProgressProvider', () {
    test('computes month spend per category over the budget limit', () async {
      final txRepo = MockTransactionsRepository();
      when(() => txRepo.getTransactions(
            from: any(named: 'from'),
            to: any(named: 'to'),
          )).thenAnswer((_) async => [
            _tx(id: 't1', category: 'Comida', amount: 30),
            _tx(id: 't2', category: 'Comida', amount: 50),
            _tx(id: 't3', category: 'Transporte', amount: 10),
            // Los ingresos no cuentan como gasto.
            _tx(
              id: 't4',
              category: 'Comida',
              amount: 999,
              type: TransactionType.income,
            ),
          ]);

      final container = makeContainer([
        currentUserProvider.overrideWith((ref) => _fakeUser),
        isProProvider.overrideWith((ref) => false),
        budgetsRepositoryProvider.overrideWith(
          (ref) => _FakeBudgetsRepo([_budget(category: 'Comida', amount: 100)]),
        ),
        currencyProvider.overrideWith(_FakeCurrency.new),
        allTransactionsProvider.overrideWith(_FakeAllTransactions.new),
        transactionsRepositoryProvider.overrideWith((ref) => txRepo),
      ]);
      final sub = container.listen(budgetProgressProvider, (_, __) {});
      addTearDown(sub.close);

      final progresses =
          await container.read(budgetProgressProvider.future);
      expect(progresses, hasLength(1));
      expect(progresses.single.spent, 80);
      expect(progresses.single.ratio, closeTo(0.8, 0.0001));
    });

    test('returns empty without budgets (no transactions query)', () async {
      final txRepo = MockTransactionsRepository();
      final container = makeContainer([
        currentUserProvider.overrideWith((ref) => _fakeUser),
        isProProvider.overrideWith((ref) => false),
        budgetsRepositoryProvider.overrideWith((ref) => _FakeBudgetsRepo()),
        currencyProvider.overrideWith(_FakeCurrency.new),
        allTransactionsProvider.overrideWith(_FakeAllTransactions.new),
        transactionsRepositoryProvider.overrideWith((ref) => txRepo),
      ]);
      final sub = container.listen(budgetProgressProvider, (_, __) {});
      addTearDown(sub.close);

      expect(await container.read(budgetProgressProvider.future), isEmpty);
      verifyNever(() => txRepo.getTransactions(
            from: any(named: 'from'),
            to: any(named: 'to'),
          ));
    });
  });

  group('BudgetAlerts', () {
    test('notifies a threshold once per budget and month', () async {
      final progress = BudgetProgress(
        budget: _budget(id: 'b1', amount: 100),
        spent: 85,
      );

      final first = await BudgetAlerts.consumeUnnotified([progress]);
      expect(first.single.$2, 80);

      final second = await BudgetAlerts.consumeUnnotified([progress]);
      expect(second, isEmpty);
    });

    test('reports 100 (not 80) when the limit is already crossed', () async {
      final progress = BudgetProgress(
        budget: _budget(id: 'b2', amount: 100),
        spent: 120,
      );

      final crossings = await BudgetAlerts.consumeUnnotified([progress]);
      expect(crossings.single.$2, 100);

      // El 80 queda absorbido: no se notifica después.
      expect(await BudgetAlerts.consumeUnnotified([progress]), isEmpty);
    });

    test('under 80% nothing is notified', () async {
      final progress = BudgetProgress(
        budget: _budget(id: 'b3', amount: 100),
        spent: 79,
      );
      expect(await BudgetAlerts.consumeUnnotified([progress]), isEmpty);
    });
  });
}
