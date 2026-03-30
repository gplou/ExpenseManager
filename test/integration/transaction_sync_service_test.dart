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

import 'package:productivity_app/core/local_db/local_database.dart';
import 'package:productivity_app/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:productivity_app/features/transactions/data/local_transactions_repository.dart';
import 'package:productivity_app/features/transactions/data/transaction_sync_service.dart';
import 'package:productivity_app/features/transactions/domain/recurring_transaction_model.dart';
import 'package:productivity_app/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:productivity_app/features/transactions/domain/transaction_model.dart';
import 'package:productivity_app/features/transactions/domain/transactions_repository_contract.dart';

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

    test('deletes cloud transactions after copying to local', () async {
      cloudTx._data.add(_tx(id: 'cloud-gone', amount: 150));

      await service.migrateToLocal();

      expect(cloudTx.all, isEmpty);
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

    test('does not clear cloud if local write fails', () async {
      // Seed cloud
      cloudTx._data.add(_tx(id: 'keep-cloud', amount: 99));

      // Poison the local tx repo so insertAll throws
      final poisonedLocalDb =
          await databaseFactoryFfi.openDatabase(':memory:');
      // Don't create schema → insertAll will fail with "no such table"
      final badLocalTx = LocalTransactionsRepository(userId: 'user-1');
      LocalDatabase.instance.setTestDb(poisonedLocalDb);

      final badService = TransactionSyncService(
        localTx: badLocalTx,
        cloudTx: cloudTx,
        localRecurring: localRecurring,
        cloudRecurring: cloudRecurring,
      );

      await expectLater(badService.migrateToLocal(), throwsA(anything));

      // Cloud data must still be there
      expect(cloudTx.all.map((t) => t.id), contains('keep-cloud'));

      // Restore good DB for tearDown
      LocalDatabase.instance.setTestDb(localDb);
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
}
