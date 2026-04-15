/// Integration tests for [OfflineAwareTransactionsRepository].
///
/// Strategy:
///   - Real SQLite in-memory DB for local reads/writes.
///   - Fake [CloudTransactionSyncContract] to assert cloud calls without network.
///   - Verifies the dual-write invariant and offline queue behaviour.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/offline_aware_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/pending_operation.dart';
import 'package:expense_manager/features/transactions/data/sync_queue_repository.dart';
import 'package:expense_manager/features/transactions/domain/cloud_transaction_sync_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Records every call so tests can assert which cloud operations were issued.
class _FakeCloudSync implements CloudTransactionSyncContract {
  final List<String> upsertedIds = [];
  final List<String> deletedIds = [];

  /// When true the next upsert/delete throws to simulate a network error.
  bool failNext = false;

  @override
  Future<void> upsertTransaction(TransactionModel transaction) async {
    if (failNext) {
      failNext = false;
      throw Exception('network error');
    }
    upsertedIds.add(transaction.id);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    if (failNext) {
      failNext = false;
      throw Exception('network error');
    }
    deletedIds.add(id);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _userId = 'user-1';

TransactionModel makeTx({
  required String id,
  double amount = 50.0,
  TransactionType type = TransactionType.expense,
  String category = 'Comida',
}) =>
    TransactionModel(
      id: id,
      userId: _userId,
      amount: amount,
      type: type,
      category: category,
      date: DateTime(2024, 6, 1),
      createdAt: DateTime(2024, 6, 1),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();

  late _FakeCloudSync cloud;
  late LocalTransactionsRepository local;
  late SyncQueueRepository queue;

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);

    cloud = _FakeCloudSync();
    local = LocalTransactionsRepository(userId: _userId);
    queue = SyncQueueRepository(userId: _userId);
  });

  tearDown(() async {
    await LocalDatabase.instance.close();
  });

  OfflineAwareTransactionsRepository makeRepo({required bool isOnline}) =>
      OfflineAwareTransactionsRepository(
        cloud: cloud,
        local: local,
        queue: queue,
        isOnline: isOnline,
      );

  // ── Reads always come from local ───────────────────────────────────────────

  group('getTransactions — always reads from local', () {
    test('returns transactions previously stored in local SQLite', () async {
      await local.createTransaction(makeTx(id: 'tx-1'));

      final results = await makeRepo(isOnline: true).getTransactions(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 12, 31),
      );

      expect(results.map((t) => t.id), contains('tx-1'));
    });

    test('returns local data even when offline', () async {
      await local.createTransaction(makeTx(id: 'tx-offline'));

      final results = await makeRepo(isOnline: false).getTransactions(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 12, 31),
      );

      expect(results.map((t) => t.id), contains('tx-offline'));
    });
  });

  // ── Online writes ──────────────────────────────────────────────────────────

  group('createTransaction — online', () {
    test('saves to local AND calls upsert on cloud', () async {
      final repo = makeRepo(isOnline: true);
      await repo.createTransaction(makeTx(id: 'tx-new'));

      final localAll = await local.getAllForUser();
      expect(localAll.map((t) => t.id), contains('tx-new'));
      expect(cloud.upsertedIds, contains('tx-new'));
    });

    test('does NOT enqueue when cloud upsert succeeds', () async {
      await makeRepo(isOnline: true).createTransaction(makeTx(id: 'tx-ok'));

      final pending = await queue.getPending();
      expect(pending, isEmpty);
    });
  });

  group('updateTransaction — online', () {
    test('updates local and calls cloud upsert', () async {
      final tx = makeTx(id: 'tx-upd');
      await local.createTransaction(tx);

      final repo = makeRepo(isOnline: true);
      await repo.updateTransaction(tx.copyWith(amount: 200));

      final all = await local.getAllForUser();
      expect(all.firstWhere((t) => t.id == 'tx-upd').amount, 200.0);
      expect(cloud.upsertedIds, contains('tx-upd'));
    });
  });

  group('deleteTransaction — online', () {
    test('removes from local and calls cloud delete', () async {
      await local.createTransaction(makeTx(id: 'tx-del'));

      await makeRepo(isOnline: true).deleteTransaction('tx-del');

      final all = await local.getAllForUser();
      expect(all.map((t) => t.id), isNot(contains('tx-del')));
      expect(cloud.deletedIds, contains('tx-del'));
    });
  });

  // ── Cloud-fail → enqueue ───────────────────────────────────────────────────
  //
  // The repository now always attempts the cloud call regardless of isOnline.
  // Enqueueing happens when the cloud call throws (network error, timeout…),
  // not based on the isOnline flag.

  group('createTransaction — cloud fails', () {
    test('saves to local and enqueues a create op when cloud throws', () async {
      cloud.failNext = true;
      await makeRepo(isOnline: false).createTransaction(makeTx(id: 'tx-q'));

      final localAll = await local.getAllForUser();
      expect(localAll.map((t) => t.id), contains('tx-q'));

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.opType, SyncOpType.create);
      expect(pending.first.entityId, 'tx-q');
    });

    test('always attempts cloud call even when isOnline is false', () async {
      // isOnline parameter is kept for API compat but ignored internally.
      await makeRepo(isOnline: false).createTransaction(makeTx(id: 'tx-nc'));
      expect(cloud.upsertedIds, contains('tx-nc'));
    });
  });

  group('updateTransaction — cloud fails', () {
    test('updates local and enqueues an update op when cloud throws', () async {
      final tx = makeTx(id: 'tx-uq');
      await local.createTransaction(tx);

      cloud.failNext = true;
      await makeRepo(isOnline: false).updateTransaction(tx.copyWith(amount: 77));

      final pending = await queue.getPending();
      expect(pending.any((op) => op.opType == SyncOpType.update), isTrue);
    });
  });

  group('deleteTransaction — cloud fails', () {
    test('removes from local and enqueues a delete op when cloud throws', () async {
      await local.createTransaction(makeTx(id: 'tx-dq'));

      cloud.failNext = true;
      await makeRepo(isOnline: false).deleteTransaction('tx-dq');

      final all = await local.getAllForUser();
      expect(all.map((t) => t.id), isNot(contains('tx-dq')));

      final pending = await queue.getPending();
      expect(pending.any((op) => op.opType == SyncOpType.delete), isTrue);
    });
  });

  // ── Online but cloud fails → enqueue ──────────────────────────────────────

  group('cloud failure while online → falls back to queue', () {
    test('enqueues create op when cloud upsert throws', () async {
      cloud.failNext = true;

      await makeRepo(isOnline: true).createTransaction(makeTx(id: 'tx-fail'));

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.opType, SyncOpType.create);
    });

    test('enqueues delete op when cloud delete throws', () async {
      await local.createTransaction(makeTx(id: 'tx-fdel'));
      cloud.failNext = true;

      await makeRepo(isOnline: true).deleteTransaction('tx-fdel');

      final pending = await queue.getPending();
      expect(pending.any((op) => op.opType == SyncOpType.delete), isTrue);
    });
  });

  // ── getSummary ─────────────────────────────────────────────────────────────

  group('getSummary', () {
    test('derives totals from local data', () async {
      await local.createTransaction(
          makeTx(id: 's1', amount: 100, type: TransactionType.income));
      await local.createTransaction(
          makeTx(id: 's2', amount: 40, type: TransactionType.expense));

      final summary = await makeRepo(isOnline: true).getSummary(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 12, 31),
      );

      expect(summary.income, 100.0);
      expect(summary.expense, 40.0);
      expect(summary.balance, 60.0);
    });
  });
}
