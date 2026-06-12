import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';

import '../helpers/local_db_helper.dart';

Map<String, Object?> _budgetRow({
  required String id,
  String userId = 'u1',
  String category = 'Comida',
  double amount = 100,
}) =>
    {
      'id': id,
      'user_id': userId,
      'category': category,
      'amount': amount,
      'period': 'monthly',
      'currency': 'EUR',
      'created_at': DateTime(2026, 6, 1).toIso8601String(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    initSqfliteFfi();
  });

  /// Una BD con el schema tal y como quedaba en v3 (sin budgets).
  Future<Database> openV3Db() async {
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    await db.execute('DROP INDEX IF EXISTS idx_budgets_user_category');
    await db.execute('DROP TABLE IF EXISTS budgets');
    addTearDown(db.close);
    return db;
  }

  group('v3 → v4 migration', () {
    test('creates the budgets table', () async {
      final db = await openV3Db();

      await LocalDatabase.applyUpgrades(db, 3, 4);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='budgets'",
      );
      expect(tables, hasLength(1));

      await db.insert('budgets', _budgetRow(id: 'b1'));
      final rows = await db.query('budgets');
      expect(rows, hasLength(1));
    });

    test('enforces one budget per (user_id, category)', () async {
      final db = await openV3Db();
      await LocalDatabase.applyUpgrades(db, 3, 4);

      await db.insert('budgets', _budgetRow(id: 'b1', category: 'Comida'));
      await expectLater(
        db.insert('budgets', _budgetRow(id: 'b2', category: 'Comida')),
        throwsA(isA<DatabaseException>()),
      );
      // Misma categoría para OTRO usuario sí está permitida.
      await db.insert(
        'budgets',
        _budgetRow(id: 'b3', userId: 'u2', category: 'Comida'),
      );
    });

    test('is idempotent (re-running the upgrade does not crash)', () async {
      final db = await openV3Db();
      await LocalDatabase.applyUpgrades(db, 3, 4);
      await LocalDatabase.applyUpgrades(db, 3, 4);
    });

    test('upgrade from v1 also ends with the budgets table', () async {
      final db = await openV3Db();
      // Simula la ruta de reparación de onCreate (pre-v2 → v4).
      await LocalDatabase.applyUpgrades(db, 1, 4);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='budgets'",
      );
      expect(tables, hasLength(1));
    });
  });

  test('clearUserData deletes only that user\'s budgets', () async {
    final db = await useInMemoryDatabase();
    await db.insert('budgets', _budgetRow(id: 'b1', userId: 'u1'));
    await db.insert('budgets', _budgetRow(id: 'b2', userId: 'u2'));

    await LocalDatabase.instance.clearUserData('u1');

    final rows = await db.query('budgets');
    expect(rows, hasLength(1));
    expect(rows.single['user_id'], 'u2');
  });
}
