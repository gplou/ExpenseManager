/// Tests for [BudgetsSyncService] — la migración FREE↔PRO de presupuestos.
///
/// El local usa una SQLite en memoria real ([LocalBudgetsRepository]); el cloud
/// es un fake en memoria ([_FakeCloudBudgetsRepo]) que implementa
/// [CloudBudgetsRepo], evitando Supabase.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/budgets/data/budgets_sync_service.dart';
import 'package:expense_manager/features/budgets/data/local_budgets_repository.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/budgets/domain/budgets_repository_contract.dart';

import '../helpers/local_db_helper.dart';

class _FakeCloudBudgetsRepo implements CloudBudgetsRepo {
  final List<BudgetModel> data = [];

  @override
  Future<BudgetModel> upsertBudget(BudgetModel budget) async {
    // Conflicto por (user_id, category): reemplaza si ya existe esa categoría.
    data.removeWhere(
      (b) => b.userId == budget.userId && b.category == budget.category,
    );
    data.add(budget);
    return budget;
  }

  @override
  Future<List<BudgetModel>> getAllForUser() async => List.of(data);

  @override
  Future<void> deleteBudget(String id) async {
    data.removeWhere((b) => b.id == id);
  }
}

BudgetModel _budget({
  String id = '',
  String userId = 'u1',
  String category = 'Comida',
  double amount = 100,
}) =>
    BudgetModel(
      id: id,
      userId: userId,
      category: category,
      amount: amount,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalBudgetsRepository local;
  late _FakeCloudBudgetsRepo cloud;
  late BudgetsSyncService service;

  setUp(() async {
    await useInMemoryDatabase();
    local = LocalBudgetsRepository(userId: 'u1');
    cloud = _FakeCloudBudgetsRepo();
    service = BudgetsSyncService(local: local, cloud: cloud);
  });

  group('migrateToCloud (FREE → PRO)', () {
    test('uploads local budgets preserving id and clears local', () async {
      final created = await local.createBudget(_budget(category: 'Comida'));
      await local.createBudget(_budget(category: 'Transporte'));

      await service.migrateToCloud();

      expect(cloud.data.map((b) => b.category), containsAll(['Comida', 'Transporte']));
      // Preserva el id local para que la UI no vea cambiar el presupuesto.
      expect(
        cloud.data.firstWhere((b) => b.category == 'Comida').id,
        created.id,
      );
      // El local queda vacío: el espejo se rehidrata luego desde el cloud.
      expect(await local.getBudgets(), isEmpty);
    });

    test('no-op when there are no local budgets', () async {
      await service.migrateToCloud();
      expect(cloud.data, isEmpty);
    });

    test('is additive — does not drop existing cloud budgets', () async {
      // Un presupuesto preexistente en la nube (periodo PRO anterior).
      cloud.data.add(_budget(id: 'cloud-1', category: 'Ocio'));
      await local.createBudget(_budget(category: 'Comida'));

      await service.migrateToCloud();

      expect(cloud.data.map((b) => b.category), containsAll(['Ocio', 'Comida']));
    });
  });

  group('migrateToLocal (PRO → FREE)', () {
    test('downloads cloud budgets to local and deletes them from cloud',
        () async {
      cloud.data.addAll([
        _budget(id: 'c1', category: 'Comida'),
        _budget(id: 'c2', category: 'Transporte'),
      ]);

      await service.migrateToLocal();

      final stored = await local.getBudgets();
      expect(stored.map((b) => b.category), ['Comida', 'Transporte']);
      expect(cloud.data, isEmpty);
    });
  });
}
