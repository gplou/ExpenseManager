/// Tests for [LocalTombstoningTransactionsRepository] — the FREE-tier repo that
/// writes to SQLite and records a delete tombstone in the sync queue so the next
/// FREE→PRO migration can remove the same rows from Supabase.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/features/transactions/data/local_tombstoning_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/pending_operation.dart';
import 'package:expense_manager/features/transactions/data/sync_queue_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

TransactionModel _tx({required String id, double amount = 50}) => TransactionModel(
      id: id,
      userId: 'user-1',
      amount: amount,
      type: TransactionType.expense,
      category: 'Comida',
      date: DateTime(2024, 3, 15),
      createdAt: DateTime(2024, 3, 15),
    );

void main() {
  sqfliteFfiInit();

  late LocalTransactionsRepository local;
  late SyncQueueRepository queue;
  late LocalTombstoningTransactionsRepository repo;

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);

    local = LocalTransactionsRepository(userId: 'user-1');
    queue = SyncQueueRepository(userId: 'user-1');
    repo = LocalTombstoningTransactionsRepository(local: local, queue: queue);
  });

  tearDown(() async {
    await LocalDatabase.instance.close();
  });

  test('delete removes the row locally AND records a delete tombstone', () async {
    await local.insertAll([_tx(id: 'tx-1')]);

    await repo.deleteTransaction('tx-1');

    // Gone from local.
    expect(await local.getAllForUser(), isEmpty);
    // Tombstone recorded for the next FREE→PRO migration.
    expect(await queue.pendingDeleteEntityIds(), contains('tx-1'));
  });

  test('the tombstone is a delete op carrying the entity id', () async {
    await local.insertAll([_tx(id: 'tx-9')]);

    await repo.deleteTransaction('tx-9');

    final pending = await queue.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.opType, SyncOpType.delete);
    expect(pending.first.entityId, 'tx-9');
  });

  test('create does not record a tombstone', () async {
    await repo.createTransaction(_tx(id: 'tx-new'));

    expect(await queue.pendingDeleteEntityIds(), isEmpty);
    expect((await local.getAllForUser()).map((t) => t.id), contains('tx-new'));
  });

  test('update does not record a tombstone', () async {
    await local.insertAll([_tx(id: 'tx-2', amount: 10)]);

    await repo.updateTransaction(_tx(id: 'tx-2', amount: 99));

    expect(await queue.pendingDeleteEntityIds(), isEmpty);
  });

  test('reads delegate to the local store', () async {
    await local.insertAll([_tx(id: 'tx-r1'), _tx(id: 'tx-r2')]);

    final all = await repo.getTransactions(
      from: DateTime(2024, 1, 1),
      to: DateTime(2024, 12, 31),
    );

    expect(all.map((t) => t.id), containsAll(['tx-r1', 'tx-r2']));
  });
}
