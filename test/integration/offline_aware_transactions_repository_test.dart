/// Integration tests for [OfflineAwareTransactionsRepository].
///
/// Strategy:
///   - Real SQLite in-memory DB for local reads/writes.
///   - Fake [CloudTransactionSyncContract] to assert cloud calls without network.
///   - Verifies the dual-write invariant and offline queue behaviour.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/errors/failures.dart';
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

/// Local repo subclass that can be forced to fail on the next write, simulating
/// SQLite being unavailable (e.g. Keystore hang or post-SQLCipher-migration
/// corruption on Android). Delegates to the real implementation otherwise.
class _FailableLocal extends LocalTransactionsRepository {
  _FailableLocal({required super.userId});
  bool failNext = false;

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw const CacheFailure('simulated local fail');
    }
  }

  @override
  Future<TransactionModel> createTransaction(TransactionModel transaction) {
    _maybeFail();
    return super.createTransaction(transaction);
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) {
    _maybeFail();
    return super.updateTransaction(transaction);
  }

  @override
  Future<void> deleteTransaction(String id) {
    _maybeFail();
    return super.deleteTransaction(id);
  }

  @override
  Future<void> upsertTransaction(TransactionModel transaction) {
    _maybeFail();
    return super.upsertTransaction(transaction);
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

  OfflineAwareTransactionsRepository makeRepo() =>
      OfflineAwareTransactionsRepository(
        cloud: cloud,
        local: local,
        queue: queue,
      );

  // ── Reads always come from local ───────────────────────────────────────────

  group('getTransactions — always reads from local', () {
    test('returns transactions previously stored in local SQLite', () async {
      await local.createTransaction(makeTx(id: 'tx-1'));

      final results = await makeRepo().getTransactions(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 12, 31),
      );

      expect(results.map((t) => t.id), contains('tx-1'));
    });

    test('returns local data even when offline', () async {
      await local.createTransaction(makeTx(id: 'tx-offline'));

      final results = await makeRepo().getTransactions(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 12, 31),
      );

      expect(results.map((t) => t.id), contains('tx-offline'));
    });
  });

  // ── Online writes ──────────────────────────────────────────────────────────

  group('createTransaction — online', () {
    test('saves to local AND calls upsert on cloud', () async {
      final repo = makeRepo();
      await repo.createTransaction(makeTx(id: 'tx-new'));

      final localAll = await local.getAllForUser();
      expect(localAll.map((t) => t.id), contains('tx-new'));
      expect(cloud.upsertedIds, contains('tx-new'));
    });

    test('does NOT enqueue when cloud upsert succeeds', () async {
      await makeRepo().createTransaction(makeTx(id: 'tx-ok'));

      final pending = await queue.getPending();
      expect(pending, isEmpty);
    });
  });

  group('updateTransaction — online', () {
    test('updates local and calls cloud upsert', () async {
      final tx = makeTx(id: 'tx-upd');
      await local.createTransaction(tx);

      final repo = makeRepo();
      await repo.updateTransaction(tx.copyWith(amount: 200));

      final all = await local.getAllForUser();
      expect(all.firstWhere((t) => t.id == 'tx-upd').amount, 200.0);
      expect(cloud.upsertedIds, contains('tx-upd'));
    });
  });

  group('deleteTransaction — online', () {
    test('removes from local and calls cloud delete', () async {
      await local.createTransaction(makeTx(id: 'tx-del'));

      await makeRepo().deleteTransaction('tx-del');

      final all = await local.getAllForUser();
      expect(all.map((t) => t.id), isNot(contains('tx-del')));
      expect(cloud.deletedIds, contains('tx-del'));
    });
  });

  // ── Cloud-fail → enqueue ───────────────────────────────────────────────────
  //
  // The repository always attempts the cloud call. Enqueueing happens when the
  // cloud call throws (network error, timeout…), not based on connectivity.

  group('createTransaction — cloud fails', () {
    test('saves to local and enqueues a create op when cloud throws', () async {
      cloud.failNext = true;
      await makeRepo().createTransaction(makeTx(id: 'tx-q'));

      final localAll = await local.getAllForUser();
      expect(localAll.map((t) => t.id), contains('tx-q'));

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.opType, SyncOpType.create);
      expect(pending.first.entityId, 'tx-q');
    });

    test('always attempts cloud call regardless of connectivity', () async {
      await makeRepo().createTransaction(makeTx(id: 'tx-nc'));
      expect(cloud.upsertedIds, contains('tx-nc'));
    });
  });

  group('updateTransaction — cloud fails', () {
    test('updates local and enqueues an update op when cloud throws', () async {
      final tx = makeTx(id: 'tx-uq');
      await local.createTransaction(tx);

      cloud.failNext = true;
      await makeRepo().updateTransaction(tx.copyWith(amount: 77));

      final pending = await queue.getPending();
      expect(pending.any((op) => op.opType == SyncOpType.update), isTrue);
    });
  });

  group('deleteTransaction — cloud fails', () {
    test('removes from local and enqueues a delete op when cloud throws', () async {
      await local.createTransaction(makeTx(id: 'tx-dq'));

      cloud.failNext = true;
      await makeRepo().deleteTransaction('tx-dq');

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

      await makeRepo().createTransaction(makeTx(id: 'tx-fail'));

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.opType, SyncOpType.create);
    });

    test('enqueues delete op when cloud delete throws', () async {
      await local.createTransaction(makeTx(id: 'tx-fdel'));
      cloud.failNext = true;

      await makeRepo().deleteTransaction('tx-fdel');

      final pending = await queue.getPending();
      expect(pending.any((op) => op.opType == SyncOpType.delete), isTrue);
    });
  });

  // ── upsertTransaction ──────────────────────────────────────────────────────

  group('upsertTransaction — online', () {
    test('saves to local and calls cloud upsert', () async {
      await makeRepo().upsertTransaction(makeTx(id: 'ups-ok'));

      final localAll = await local.getAllForUser();
      expect(localAll.map((t) => t.id), contains('ups-ok'));
      expect(cloud.upsertedIds, contains('ups-ok'));
    });

    test('does not enqueue when cloud upsert succeeds', () async {
      await makeRepo().upsertTransaction(makeTx(id: 'ups-clean'));

      expect(await queue.getPending(), isEmpty);
    });
  });

  group('upsertTransaction — cloud fails', () {
    test('saves to local and enqueues an update op when cloud throws', () async {
      cloud.failNext = true;
      await makeRepo().upsertTransaction(makeTx(id: 'ups-fail'));

      final localAll = await local.getAllForUser();
      expect(localAll.map((t) => t.id), contains('ups-fail'));

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.opType, SyncOpType.update);
      expect(pending.first.entityId, 'ups-fail');
    });
  });

  // ── Local fails → cloud-only fallback ──────────────────────────────────────
  //
  // When SQLite is unavailable (Keystore hang, post-SQLCipher-migration
  // corruption…) the write must still reach Supabase so the user doesn't lose
  // the transaction. Enqueueing is skipped because the queue lives in the same
  // SQLite DB and would also fail.

  group('createTransaction — local fails', () {
    test('still upserts to cloud with the stamped id', () async {
      final failableLocal = _FailableLocal(userId: _userId)..failNext = true;
      final repo = OfflineAwareTransactionsRepository(
        cloud: cloud,
        local: failableLocal,
        queue: queue,
      );

      final saved = await repo.createTransaction(makeTx(id: 'tx-local-fail'));

      expect(saved.id, 'tx-local-fail');
      expect(cloud.upsertedIds, contains('tx-local-fail'));
      expect(await queue.getPending(), isEmpty);
    });

    test('stamps a UUID v4 id when caller passes empty id', () async {
      final failableLocal = _FailableLocal(userId: _userId)..failNext = true;
      final repo = OfflineAwareTransactionsRepository(
        cloud: cloud,
        local: failableLocal,
        queue: queue,
      );

      final saved = await repo.createTransaction(makeTx(id: ''));

      final uuidV4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuidV4.hasMatch(saved.id), isTrue,
          reason: 'id "${saved.id}" should be UUID v4');
      expect(saved.userId, _userId);
      expect(cloud.upsertedIds.single, saved.id);
    });

    test('rethrows when both local AND cloud fail', () async {
      final failableLocal = _FailableLocal(userId: _userId)..failNext = true;
      cloud.failNext = true;
      final repo = OfflineAwareTransactionsRepository(
        cloud: cloud,
        local: failableLocal,
        queue: queue,
      );

      await expectLater(
        repo.createTransaction(makeTx(id: 'tx-both-fail')),
        throwsA(isA<Exception>()),
      );
      expect(await queue.getPending(), isEmpty);
    });
  });

  group('updateTransaction — local fails', () {
    test('still upserts to cloud with the passed id', () async {
      final failableLocal = _FailableLocal(userId: _userId)..failNext = true;
      final repo = OfflineAwareTransactionsRepository(
        cloud: cloud,
        local: failableLocal,
        queue: queue,
      );

      await repo.updateTransaction(makeTx(id: 'tx-upd-lf'));

      expect(cloud.upsertedIds, contains('tx-upd-lf'));
      expect(await queue.getPending(), isEmpty);
    });
  });

  group('deleteTransaction — local fails', () {
    test('still issues cloud delete', () async {
      final failableLocal = _FailableLocal(userId: _userId)..failNext = true;
      final repo = OfflineAwareTransactionsRepository(
        cloud: cloud,
        local: failableLocal,
        queue: queue,
      );

      await repo.deleteTransaction('tx-del-lf');

      expect(cloud.deletedIds, contains('tx-del-lf'));
      expect(await queue.getPending(), isEmpty);
    });
  });

  group('upsertTransaction — local fails', () {
    test('still upserts to cloud', () async {
      final failableLocal = _FailableLocal(userId: _userId)..failNext = true;
      final repo = OfflineAwareTransactionsRepository(
        cloud: cloud,
        local: failableLocal,
        queue: queue,
      );

      await repo.upsertTransaction(makeTx(id: 'tx-ups-lf'));

      expect(cloud.upsertedIds, contains('tx-ups-lf'));
      expect(await queue.getPending(), isEmpty);
    });
  });

  // ── getSummary ─────────────────────────────────────────────────────────────

  group('getSummary', () {
    test('derives totals from local data', () async {
      await local.createTransaction(
          makeTx(id: 's1', amount: 100, type: TransactionType.income));
      await local.createTransaction(
          makeTx(id: 's2', amount: 40, type: TransactionType.expense));

      final summary = await makeRepo().getSummary(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 12, 31),
      );

      expect(summary.income, 100.0);
      expect(summary.expense, 40.0);
      expect(summary.balance, 60.0);
    });
  });
}
