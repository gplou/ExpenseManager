/// Tests for [TransactionSyncService].
///
/// Two in-memory SQLite databases are used:
///   - [_localDb]  — simulates the device-local store
///   - [_cloudDb]  — simulates the Supabase-backed store (via a second
///                   LocalDatabase singleton-replacement)
///
/// The trick: [TransactionSyncService] accepts [TransactionsRepositoryContract]
/// for its cloud tx repo, so we can pass a [LocalTransactionsRepository] backed
/// by a different DB as a stand-in. For cloud recurring we use a dedicated
/// [_FakeCloudRecurringRepo] that holds data in memory, bypassing Supabase.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/transaction_sync_service.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';

// ── In-memory cloud fakes ─────────────────────────────────────────────────────

/// A simple in-memory implementation of [TransactionsRepositoryContract] that
/// acts as the "cloud" side in sync tests — no Supabase required.
class _FakeCloudTxRepo implements TransactionsRepositoryContract {
  final List<TransactionModel> _data = [];

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) async =>
      List.of(_data);

  @override
  Future<TransactionsSummary> getSummary(
      {required DateTime from, required DateTime to}) async {
    double income = 0;
    double expense = 0;
    for (final t in _data) {
      if (t.type.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return TransactionsSummary(income: income, expense: expense);
  }

  @override
  Future<TransactionModel> createTransaction(TransactionModel t) async {
    _data.add(t);
    return t;
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) async {
    _data.removeWhere((e) => e.id == t.id);
    _data.add(t);
    return t;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _data.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> upsertTransaction(TransactionModel t) async {
    _data.removeWhere((e) => e.id == t.id);
    _data.add(t);
  }

  List<TransactionModel> get all => List.unmodifiable(_data);
}

/// A fake cloud recurring repo that stores data in memory.
/// Implements the contract directly so no Supabase client is needed.
class _FakeCloudRecurringRepo implements RecurringTransactionsRepositoryContract {
  final List<RecurringTransactionModel> _data = [];
  int _seq = 0;

  @override
  Future<List<RecurringTransactionModel>> getDueRecurring() async =>
      List.of(_data);

  @override
  Future<List<RecurringTransactionModel>> getAllForUser() async =>
      List.of(_data);

  @override
  Future<String> createRecurring({
    required double amount,
    required TransactionType type,
    required String category,
    String? subcategory,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  }) async {
    final id = 'cloud-r-${++_seq}';
    _data.add(RecurringTransactionModel(
      id: id,
      userId: 'user-1',
      amount: amount,
      type: type,
      category: category,
      subcategory: subcategory,
      description: description,
      recurrenceType: recurrenceType,
      nextOccurrence: nextOccurrence,
      createdAt: DateTime.now(),
    ));
    return id;
  }

  @override
  Future<RecurringTransactionModel?> getById(String id) async =>
      _data.where((r) => r.id == id).firstOrNull;

  @override
  Future<void> updateRecurring({
    required String id,
    required double amount,
    required TransactionType type,
    required String category,
    String? subcategory,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  }) async {}

  @override
  Future<void> updateNextOccurrence(String id, DateTime next) async {}

  @override
  Future<void> deleteRecurring(String id) async {
    _data.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> upsertRecurring(RecurringTransactionModel model) async {
    _data.removeWhere((r) => r.id == model.id);
    _data.add(model);
  }

  List<RecurringTransactionModel> get all => List.unmodifiable(_data);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

TransactionModel _tx({
  required String id,
  double amount = 50,
  TransactionType type = TransactionType.expense,
}) =>
    TransactionModel(
      id: id,
      userId: 'user-1',
      amount: amount,
      type: type,
      category: 'Comida',
      date: DateTime(2024, 3, 15),
      createdAt: DateTime(2024, 3, 15),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();

  late Database localDb;
  late LocalTransactionsRepository localTx;
  late LocalRecurringTransactionsRepository localRecurring;
  late _FakeCloudTxRepo cloudTx;
  late _FakeCloudRecurringRepo cloudRecurring;
  late TransactionSyncService service;

  setUp(() async {
    localDb = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(localDb);
    LocalDatabase.instance.setTestDb(localDb);

    localTx = LocalTransactionsRepository(userId: 'user-1');
    localRecurring = LocalRecurringTransactionsRepository(userId: 'user-1');
    cloudTx = _FakeCloudTxRepo();
    cloudRecurring = _FakeCloudRecurringRepo();

    service = TransactionSyncService(
      localTx: localTx,
      cloudTx: cloudTx,
      localRecurring: localRecurring,
      cloudRecurring: cloudRecurring,
    );
  });

  tearDown(() async {
    await LocalDatabase.instance.close();
  });

  // ── migrateToCloud (free → PRO) ────────────────────────────────────────────

  group('migrateToCloud (free → PRO)', () {
    test('copies all local transactions to cloud', () async {
      await localTx.insertAll([
        _tx(id: 't1', amount: 100),
        _tx(id: 't2', amount: 200),
      ]);

      await service.migrateToCloud();

      expect(cloudTx.all.map((t) => t.id), containsAll(['t1', 't2']));
    });

    test('clears local transactions after copying', () async {
      await localTx.insertAll([_tx(id: 'gone', amount: 50)]);

      await service.migrateToCloud();

      expect(await localTx.getAllForUser(), isEmpty);
    });

    test('copies local recurring transactions to cloud', () async {
      await localRecurring.insertAll([
        RecurringTransactionModel(
          id: 'rec-local',
          userId: 'user-1',
          amount: 80,
          type: TransactionType.expense,
          category: 'Transporte',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 5, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
      ]);

      await service.migrateToCloud();

      expect(cloudRecurring.all.length, 1);
      expect(cloudRecurring.all.first.amount, 80.0);
    });

    test('clears local recurring after copying', () async {
      await localRecurring.insertAll([
        RecurringTransactionModel(
          id: 'rec-gone',
          userId: 'user-1',
          amount: 30,
          type: TransactionType.expense,
          category: 'Suscripción',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 5, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
      ]);

      await service.migrateToCloud();

      expect(await localRecurring.getAllForUser(), isEmpty);
    });

    test('is a no-op when local has no data', () async {
      await service.migrateToCloud();

      expect(cloudTx.all, isEmpty);
      expect(cloudRecurring.all, isEmpty);
    });

    test('preserves UUIDs for transactions (no new Supabase-generated IDs)', () async {
      await localTx.insertAll([_tx(id: 'uuid-tx-1'), _tx(id: 'uuid-tx-2')]);
      await service.migrateToCloud();
      expect(cloudTx.all.map((t) => t.id), containsAll(['uuid-tx-1', 'uuid-tx-2']));
    });

    test('preserves UUIDs for recurring transactions', () async {
      await localRecurring.insertAll([
        RecurringTransactionModel(
          id: 'uuid-rec-1',
          userId: 'user-1',
          amount: 50,
          type: TransactionType.expense,
          category: 'Suscripción',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 6, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
      ]);
      await service.migrateToCloud();
      expect(cloudRecurring.all.map((r) => r.id), contains('uuid-rec-1'));
    });

    test('does not delete cloud rows that are absent locally (additive merge)',
        () async {
      // Regression guard: migrateToCloud also runs on a PRO cold start where
      // local may be a partial/empty view of the cloud. It must never wipe
      // cloud rows just because they are missing from the local snapshot.
      cloudTx._data.addAll([
        _tx(id: 'cloud-only-1', amount: 100),
        _tx(id: 'cloud-only-2', amount: 200),
      ]);
      // Local has NO transactions.

      await service.migrateToCloud();

      expect(cloudTx.all.map((t) => t.id),
          containsAll(['cloud-only-1', 'cloud-only-2']),
          reason: 'cloud rows must survive an additive migrateToCloud');
    });

    test('does not delete cloud recurring that is absent locally', () async {
      cloudRecurring._data.add(RecurringTransactionModel(
        id: 'cloud-only-rec',
        userId: 'user-1',
        amount: 30,
        type: TransactionType.expense,
        category: 'Suscripción',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 5, 1),
        createdAt: DateTime(2024, 1, 1),
      ));
      // Local has no recurring rows.

      await service.migrateToCloud();

      expect(cloudRecurring.all.map((r) => r.id), contains('cloud-only-rec'));
    });

    test('replays delete tombstones: removes those ids from the cloud only',
        () async {
      // Simulates PRO→FREE→PRO: cloud still holds rows from the prior PRO
      // period; while FREE the user deleted 'deleted-while-free' and kept 'kept'.
      cloudTx._data.addAll([
        _tx(id: 'kept', amount: 100),
        _tx(id: 'deleted-while-free', amount: 200),
      ]);
      await localTx.insertAll([_tx(id: 'kept', amount: 100)]);

      await service.migrateToCloud(
        deletedTransactionIds: ['deleted-while-free'],
      );

      final cloudIds = cloudTx.all.map((t) => t.id);
      expect(cloudIds, contains('kept'));
      expect(cloudIds, isNot(contains('deleted-while-free')),
          reason: 'explicitly tombstoned id must be removed from the cloud');
    });

    test('a tombstone never deletes a row that still exists locally', () async {
      // Defensive: an id that was deleted then re-created locally must survive.
      cloudTx._data.add(_tx(id: 're-created', amount: 50));
      await localTx.insertAll([_tx(id: 're-created', amount: 50)]);

      await service.migrateToCloud(deletedTransactionIds: ['re-created']);

      expect(cloudTx.all.map((t) => t.id), contains('re-created'),
          reason: 'local presence wins over a stale tombstone');
    });

    test('tombstone for an id absent from the cloud is a harmless no-op',
        () async {
      cloudTx._data.add(_tx(id: 'survivor', amount: 10));

      await service.migrateToCloud(deletedTransactionIds: ['never-existed']);

      expect(cloudTx.all.map((t) => t.id), contains('survivor'));
    });

    test('replays recurring delete tombstones: removes those ids from the cloud',
        () async {
      cloudRecurring._data.addAll([
        RecurringTransactionModel(
          id: 'rec-kept',
          userId: 'user-1',
          amount: 10,
          type: TransactionType.expense,
          category: 'Suscripción',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 5, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
        RecurringTransactionModel(
          id: 'rec-deleted-while-free',
          userId: 'user-1',
          amount: 20,
          type: TransactionType.expense,
          category: 'Suscripción',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 5, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
      ]);
      await localRecurring.insertAll([
        RecurringTransactionModel(
          id: 'rec-kept',
          userId: 'user-1',
          amount: 10,
          type: TransactionType.expense,
          category: 'Suscripción',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 5, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
      ]);

      await service.migrateToCloud(
        deletedRecurringIds: ['rec-deleted-while-free'],
      );

      final ids = cloudRecurring.all.map((r) => r.id);
      expect(ids, contains('rec-kept'));
      expect(ids, isNot(contains('rec-deleted-while-free')));
    });

    test('a recurring tombstone never deletes a recurring still present locally',
        () async {
      cloudRecurring._data.add(RecurringTransactionModel(
        id: 'rec-recreated',
        userId: 'user-1',
        amount: 20,
        type: TransactionType.expense,
        category: 'Suscripción',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 5, 1),
        createdAt: DateTime(2024, 1, 1),
      ));
      await localRecurring.insertAll([
        RecurringTransactionModel(
          id: 'rec-recreated',
          userId: 'user-1',
          amount: 20,
          type: TransactionType.expense,
          category: 'Suscripción',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 5, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
      ]);

      await service.migrateToCloud(deletedRecurringIds: ['rec-recreated']);

      expect(cloudRecurring.all.map((r) => r.id), contains('rec-recreated'),
          reason: 'local presence wins over a stale recurring tombstone');
    });

    test('does not clear local if cloud write fails', () async {
      // Replace cloudTx with one that throws on write
      final failingCloud = _ThrowingCloudTxRepo();
      final failingService = TransactionSyncService(
        localTx: localTx,
        cloudTx: failingCloud,
        localRecurring: localRecurring,
        cloudRecurring: cloudRecurring,
      );

      await localTx.insertAll([_tx(id: 'safe', amount: 10)]);

      await expectLater(failingService.migrateToCloud(), throwsA(anything));

      // Local data must still be there
      expect(await localTx.getAllForUser(), isNotEmpty);
    });
  });

  // ── migrateToLocal (PRO → free) ────────────────────────────────────────────

  group('migrateToLocal (PRO → free)', () {
    test('copies all cloud transactions to local', () async {
      cloudTx._data.addAll([
        _tx(id: 'c1', amount: 300),
        _tx(id: 'c2', amount: 400),
      ]);

      await service.migrateToLocal();

      final localAll = await localTx.getAllForUser();
      expect(localAll.map((t) => t.id), containsAll(['c1', 'c2']));
    });

    test('preserves cloud transactions after copying to local (cloud is a '
        'read-only backup while FREE)', () async {
      cloudTx._data.add(_tx(id: 'cloud-keep', amount: 150));

      await service.migrateToLocal();

      // La nube ya NO se borra: queda intacta como respaldo. Al volver a PRO,
      // migrateToCloud reconcilia con upsert aditivo por id.
      expect(cloudTx.all.map((t) => t.id), contains('cloud-keep'));
      expect((await localTx.getAllForUser()).map((t) => t.id),
          contains('cloud-keep'));
    });

    test('copies cloud recurring to local', () async {
      cloudRecurring._data.add(RecurringTransactionModel(
        id: 'cloud-rec',
        userId: 'user-1',
        amount: 120,
        type: TransactionType.income,
        category: 'Salario',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 5, 1),
        createdAt: DateTime(2024, 1, 1),
      ));

      await service.migrateToLocal();

      final localRecAll = await localRecurring.getAllForUser();
      expect(localRecAll.length, 1);
      expect(localRecAll.first.id, 'cloud-rec');
    });

    test('is a no-op when cloud has no data', () async {
      await service.migrateToLocal();

      expect(await localTx.getAllForUser(), isEmpty);
      expect(await localRecurring.getAllForUser(), isEmpty);
    });

    test('cloud stays intact even if local write fails', () async {
      // migrateToLocal nunca borra la nube; aunque la escritura local falle,
      // la nube permanece como respaldo.
      cloudTx._data.add(_tx(id: 'keep-cloud', amount: 99));

      // Use a local tx repo that always throws on insertAll to simulate
      // a write failure (e.g. disk full, schema mismatch). sqflite_ffi
      // does not reliably propagate "no such table" errors through batch
      // commits on all platforms, so we use an explicit throwing fake.
      final badService = TransactionSyncService(
        localTx: _ThrowingLocalTxRepo(userId: 'user-1'),
        cloudTx: cloudTx,
        localRecurring: localRecurring,
        cloudRecurring: cloudRecurring,
      );

      await expectLater(badService.migrateToLocal(), throwsA(anything));

      // Cloud data must still be there — local failure must not trigger deletion.
      expect(cloudTx.all.map((t) => t.id), contains('keep-cloud'));
    });
  });

  // ── Multi-user isolation ───────────────────────────────────────────────────
  //
  // The SQLite database is shared on the device. These tests verify that a
  // migration for one user never reads, writes, or deletes another user's rows.

  group('multi-user isolation', () {
    late LocalTransactionsRepository user2Tx;
    late LocalRecurringTransactionsRepository user2Recurring;

    // A transaction owned by user-2.
    TransactionModel tx2({required String id, double amount = 50}) =>
        TransactionModel(
          id: id,
          userId: 'user-2',
          amount: amount,
          type: TransactionType.expense,
          category: 'Comida',
          date: DateTime(2024, 3, 15),
          createdAt: DateTime(2024, 3, 15),
        );

    RecurringTransactionModel rec2({required String id}) =>
        RecurringTransactionModel(
          id: id,
          userId: 'user-2',
          amount: 30,
          type: TransactionType.expense,
          category: 'Transporte',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 5, 1),
          createdAt: DateTime(2024, 1, 1),
        );

    setUp(() {
      user2Tx = LocalTransactionsRepository(userId: 'user-2');
      user2Recurring = LocalRecurringTransactionsRepository(userId: 'user-2');
    });

    test('migrateToCloud only uploads and clears data for the target user', () async {
      // Both users have local transactions.
      await localTx.insertAll([_tx(id: 'u1-t1', amount: 100)]);
      await user2Tx.insertAll([tx2(id: 'u2-t1', amount: 200)]);

      // Migrate user-1 to cloud.
      await service.migrateToCloud();

      // Cloud received user-1's data only.
      expect(cloudTx.all.map((t) => t.id), contains('u1-t1'));
      expect(cloudTx.all.map((t) => t.id), isNot(contains('u2-t1')));

      // user-1 local cleared; user-2 local untouched.
      expect(await localTx.getAllForUser(), isEmpty);
      final u2Data = await user2Tx.getAllForUser();
      expect(u2Data.map((t) => t.id), contains('u2-t1'));
    });

    test('migrateToCloud only clears recurring transactions for the target user',
        () async {
      await localRecurring.insertAll([
        RecurringTransactionModel(
          id: 'u1-rec',
          userId: 'user-1',
          amount: 80,
          type: TransactionType.expense,
          category: 'Transporte',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 5, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
      ]);
      await user2Recurring.insertAll([rec2(id: 'u2-rec')]);

      await service.migrateToCloud();

      // user-1 recurring cleared.
      expect(await localRecurring.getAllForUser(), isEmpty);
      // user-2 recurring untouched.
      final u2Recs = await user2Recurring.getAllForUser();
      expect(u2Recs.map((r) => r.id), contains('u2-rec'));
    });

    test('migrateToLocal does not disturb other users local data', () async {
      // user-2 already has local data.
      await user2Tx.insertAll([tx2(id: 'u2-existing')]);
      await user2Recurring.insertAll([rec2(id: 'u2-rec-existing')]);

      // Cloud has user-1 data to download.
      cloudTx._data.add(_tx(id: 'u1-cloud', amount: 300));

      await service.migrateToLocal();

      // user-1 data is now local.
      final u1Data = await localTx.getAllForUser();
      expect(u1Data.map((t) => t.id), contains('u1-cloud'));

      // user-2 data completely untouched.
      final u2Data = await user2Tx.getAllForUser();
      expect(u2Data.length, 1);
      expect(u2Data.first.id, 'u2-existing');
      final u2Recs = await user2Recurring.getAllForUser();
      expect(u2Recs.length, 1);
      expect(u2Recs.first.id, 'u2-rec-existing');
    });
  });
}

// ── Helper: cloud tx repo that always throws ──────────────────────────────────

class _ThrowingCloudTxRepo implements TransactionsRepositoryContract {
  @override
  Future<List<TransactionModel>> getTransactions(
          {required DateTime from, required DateTime to}) async =>
      [];

  @override
  Future<TransactionsSummary> getSummary(
          {required DateTime from, required DateTime to}) async =>
      const TransactionsSummary(income: 0, expense: 0);

  @override
  Future<TransactionModel> createTransaction(TransactionModel t) {
    throw Exception('cloud write failed');
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) {
    throw Exception('cloud write failed');
  }

  @override
  Future<void> deleteTransaction(String id) async {}

  @override
  Future<void> upsertTransaction(TransactionModel t) {
    throw Exception('cloud write failed');
  }
}

// ── Helper: local tx repo whose insertAll always throws ───────────────────────

class _ThrowingLocalTxRepo extends LocalTransactionsRepository {
  _ThrowingLocalTxRepo({required super.userId});

  @override
  Future<void> insertAll(List<TransactionModel> transactions) {
    throw Exception('local write failed');
  }
}
