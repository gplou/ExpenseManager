import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/budgets/data/local_budgets_repository.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';

import '../helpers/local_db_helper.dart';

BudgetModel _budget({
  String id = '',
  String userId = '',
  String category = 'Comida',
  double amount = 100,
  String currency = 'EUR',
}) =>
    BudgetModel(
      id: id,
      userId: userId,
      category: category,
      amount: amount,
      currency: currency,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalBudgetsRepository repo;

  setUp(() async {
    await useInMemoryDatabase();
    repo = LocalBudgetsRepository(userId: 'u1');
  });

  test('createBudget stamps id, userId and createdAt', () async {
    final fixed = DateTime(2026, 6, 12, 10);
    final created = await withClock(Clock.fixed(fixed), () {
      return repo.createBudget(_budget());
    });

    expect(created.id, isNotEmpty);
    expect(created.userId, 'u1');
    expect(created.createdAt, fixed);

    final stored = await repo.getBudgets();
    expect(stored.single.id, created.id);
  });

  test('getBudgets returns only own budgets, sorted by category', () async {
    await repo.createBudget(_budget(category: 'Transporte'));
    await repo.createBudget(_budget(category: 'Comida'));
    final other = LocalBudgetsRepository(userId: 'u2');
    await other.createBudget(_budget(category: 'Ocio'));

    final budgets = await repo.getBudgets();
    expect(budgets.map((b) => b.category), ['Comida', 'Transporte']);
  });

  test('updateBudget persists the new amount', () async {
    final created = await repo.createBudget(_budget(amount: 100));
    await repo.updateBudget(created.copyWith(amount: 250));

    final stored = await repo.getBudgets();
    expect(stored.single.amount, 250);
  });

  test('deleteBudget removes the row', () async {
    final created = await repo.createBudget(_budget());
    await repo.deleteBudget(created.id);
    expect(await repo.getBudgets(), isEmpty);
  });

  test('replaceAll swaps the mirror contents for the user', () async {
    await repo.createBudget(_budget(category: 'Comida'));
    final other = LocalBudgetsRepository(userId: 'u2');
    final keep = await other.createBudget(_budget(category: 'Ocio'));

    await repo.replaceAll([
      _budget(id: 'cloud-1', userId: 'u1', category: 'Transporte'),
    ]);

    final mine = await repo.getBudgets();
    expect(mine.map((b) => b.id), ['cloud-1']);
    // El espejo de otro usuario queda intacto.
    expect((await other.getBudgets()).single.id, keep.id);
  });
}
