// Unit tests for LocalDatabase.clearUserData.
// Verifies that only the target user's rows are deleted across all three tables,
// leaving rows from other users intact.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';

void main() {
  sqfliteFfiInit();

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);
  });

  tearDown(() async {
    await LocalDatabase.instance.close();
  });

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<void> insertTransaction(String id, String userId) async {
    final db = await LocalDatabase.instance.db;
    await db.insert('transactions', {
      'id': id,
      'user_id': userId,
      'amount': 10.0,
      'type': 'expense',
      'category': 'Food',
      'date': '2024-06-01',
      'created_at': '2024-06-01T00:00:00.000',
      'currency': 'EUR',
    });
  }

  Future<void> insertRecurring(String id, String userId) async {
    final db = await LocalDatabase.instance.db;
    await db.insert('recurring_transactions', {
      'id': id,
      'user_id': userId,
      'amount': 20.0,
      'type': 'expense',
      'category': 'Housing',
      'recurrence_type': 'monthly',
      'next_occurrence': '2024-07-01',
      'created_at': '2024-06-01T00:00:00.000',
    });
  }

  Future<void> insertPending(String id, String userId) async {
    final db = await LocalDatabase.instance.db;
    await db.insert('pending_operations', {
      'id': id,
      'user_id': userId,
      'op_type': 'create',
      'entity_id': 'tx-$id',
      'created_at': '2024-06-01T00:00:00.000',
      'attempts': 0,
    });
  }

  Future<int> countRows(String table, String userId) async {
    final db = await LocalDatabase.instance.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM $table WHERE user_id = ?',
      [userId],
    );
    return result.first['c'] as int;
  }

  // ── tests ──────────────────────────────────────────────────────────────────

  group('LocalDatabase.clearUserData', () {
    test('deletes transactions only for the target user', () async {
      await insertTransaction('tx-1', 'user-A');
      await insertTransaction('tx-2', 'user-A');
      await insertTransaction('tx-3', 'user-B');

      await LocalDatabase.instance.clearUserData('user-A');

      expect(await countRows('transactions', 'user-A'), 0);
      expect(await countRows('transactions', 'user-B'), 1);
    });

    test('deletes recurring_transactions only for the target user', () async {
      await insertRecurring('rt-1', 'user-A');
      await insertRecurring('rt-2', 'user-B');

      await LocalDatabase.instance.clearUserData('user-A');

      expect(await countRows('recurring_transactions', 'user-A'), 0);
      expect(await countRows('recurring_transactions', 'user-B'), 1);
    });

    test('deletes pending_operations only for the target user', () async {
      await insertPending('po-1', 'user-A');
      await insertPending('po-2', 'user-B');

      await LocalDatabase.instance.clearUserData('user-A');

      expect(await countRows('pending_operations', 'user-A'), 0);
      expect(await countRows('pending_operations', 'user-B'), 1);
    });

    test('clears all three tables in a single call', () async {
      await insertTransaction('tx-1', 'user-A');
      await insertRecurring('rt-1', 'user-A');
      await insertPending('po-1', 'user-A');

      await LocalDatabase.instance.clearUserData('user-A');

      expect(await countRows('transactions', 'user-A'), 0);
      expect(await countRows('recurring_transactions', 'user-A'), 0);
      expect(await countRows('pending_operations', 'user-A'), 0);
    });

    test('is a no-op when the user has no data', () async {
      // Should complete without throwing
      await expectLater(
        LocalDatabase.instance.clearUserData('user-nonexistent'),
        completes,
      );
    });

    test('does not affect other users when multiple accounts exist', () async {
      // Three accounts with data
      for (final uid in ['user-A', 'user-B', 'user-C']) {
        await insertTransaction('tx-$uid', uid);
        await insertRecurring('rt-$uid', uid);
        await insertPending('po-$uid', uid);
      }

      await LocalDatabase.instance.clearUserData('user-B');

      // user-A and user-C untouched
      for (final uid in ['user-A', 'user-C']) {
        expect(await countRows('transactions', uid), 1, reason: '$uid transactions');
        expect(await countRows('recurring_transactions', uid), 1,
            reason: '$uid recurring');
        expect(await countRows('pending_operations', uid), 1,
            reason: '$uid pending');
      }
      // user-B cleared
      expect(await countRows('transactions', 'user-B'), 0);
      expect(await countRows('recurring_transactions', 'user-B'), 0);
      expect(await countRows('pending_operations', 'user-B'), 0);
    });
  });
}
