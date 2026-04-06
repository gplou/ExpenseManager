import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

TransactionModel _tx({
  required String id,
  required double amount,
  required TransactionType type,
  String userId = 'user-1',
  String category = 'Comida',
  DateTime? date,
}) =>
    TransactionModel(
      id: id,
      userId: userId,
      amount: amount,
      type: type,
      category: category,
      date: date ?? DateTime(2024, 3, 15),
      createdAt: DateTime(2024, 3, 15),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();

  late LocalTransactionsRepository repo;

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);
    repo = LocalTransactionsRepository(userId: 'user-1');
  });

  tearDown(() async {
    await LocalDatabase.instance.close();
  });

  // ── createTransaction ──────────────────────────────────────────────────────

  group('createTransaction', () {
    test('stores and returns the transaction', () async {
      final tx = _tx(id: 'tx-1', amount: 50, type: TransactionType.expense);
      final result = await repo.createTransaction(tx);

      expect(result.id, 'tx-1');
      expect(result.amount, 50.0);
      expect(result.type, TransactionType.expense);
      expect(result.userId, 'user-1');
    });

    test('generates an id when the given id is empty', () async {
      final tx = _tx(id: '', amount: 100, type: TransactionType.income);
      final result = await repo.createTransaction(tx);

      expect(result.id, isNotEmpty);
      expect(result.amount, 100.0);
    });

    test('persists so it appears in subsequent reads', () async {
      await repo.createTransaction(
          _tx(id: 'tx-persist', amount: 99, type: TransactionType.income));

      final all = await repo.getAllForUser();
      expect(all.map((t) => t.id), contains('tx-persist'));
    });

    test('replaces an existing row with the same id (idempotent)', () async {
      final tx = _tx(id: 'dup', amount: 10, type: TransactionType.expense);
      await repo.createTransaction(tx);
      await repo.createTransaction(tx.copyWith(amount: 20));

      final all = await repo.getAllForUser();
      final found = all.where((t) => t.id == 'dup').toList();
      expect(found.length, 1);
      expect(found.first.amount, 20.0);
    });
  });

  // ── getTransactions ────────────────────────────────────────────────────────

  group('getTransactions', () {
    test('returns only transactions within the date range', () async {
      await repo.createTransaction(
          _tx(id: 'in', amount: 10, type: TransactionType.income,
              date: DateTime(2024, 3, 15)));
      await repo.createTransaction(
          _tx(id: 'before', amount: 20, type: TransactionType.income,
              date: DateTime(2024, 2, 28)));
      await repo.createTransaction(
          _tx(id: 'after', amount: 30, type: TransactionType.income,
              date: DateTime(2024, 4, 1)));

      final results = await repo.getTransactions(
        from: DateTime(2024, 3, 1),
        to: DateTime(2024, 3, 31),
      );

      expect(results.map((t) => t.id), contains('in'));
      expect(results.map((t) => t.id), isNot(contains('before')));
      expect(results.map((t) => t.id), isNot(contains('after')));
    });

    test('returns empty list when no transactions exist in range', () async {
      final results = await repo.getTransactions(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 31),
      );
      expect(results, isEmpty);
    });

    test('does not return transactions for a different user', () async {
      final otherRepo = LocalTransactionsRepository(userId: 'user-2');
      await otherRepo.createTransaction(
          _tx(id: 'other-tx', amount: 55, type: TransactionType.expense,
              userId: 'user-2'));

      final results = await repo.getTransactions(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 12, 31),
      );
      expect(results.map((t) => t.id), isNot(contains('other-tx')));
    });

    test('orders by date descending', () async {
      await repo.createTransaction(
          _tx(id: 'early', amount: 10, type: TransactionType.income,
              date: DateTime(2024, 3, 1)));
      await repo.createTransaction(
          _tx(id: 'late', amount: 20, type: TransactionType.income,
              date: DateTime(2024, 3, 20)));

      final results = await repo.getTransactions(
        from: DateTime(2024, 3, 1),
        to: DateTime(2024, 3, 31),
      );
      expect(results.first.id, 'late');
      expect(results.last.id, 'early');
    });
  });

  // ── updateTransaction ──────────────────────────────────────────────────────

  group('updateTransaction', () {
    test('updates the amount of an existing transaction', () async {
      final tx = _tx(id: 'upd', amount: 50, type: TransactionType.expense);
      await repo.createTransaction(tx);

      await repo.updateTransaction(tx.copyWith(amount: 75));

      final all = await repo.getAllForUser();
      expect(all.firstWhere((t) => t.id == 'upd').amount, 75.0);
    });

    test('updating returns the new model', () async {
      final tx = _tx(id: 'upd2', amount: 100, type: TransactionType.income);
      await repo.createTransaction(tx);

      final updated =
          await repo.updateTransaction(tx.copyWith(category: 'Salario'));
      expect(updated.category, 'Salario');
    });

    test('does not affect other users rows', () async {
      final otherRepo = LocalTransactionsRepository(userId: 'user-2');
      final otherTx =
          _tx(id: 'other', amount: 200, type: TransactionType.income,
              userId: 'user-2');
      await otherRepo.createTransaction(otherTx);

      // user-1 tries to update user-2 row (nothing should happen)
      await repo.updateTransaction(otherTx.copyWith(amount: 1));

      final result = (await otherRepo.getAllForUser())
          .firstWhere((t) => t.id == 'other');
      expect(result.amount, 200.0);
    });
  });

  // ── deleteTransaction ──────────────────────────────────────────────────────

  group('deleteTransaction', () {
    test('removes the row', () async {
      await repo
          .createTransaction(_tx(id: 'del', amount: 10, type: TransactionType.expense));
      await repo.deleteTransaction('del');

      final all = await repo.getAllForUser();
      expect(all.map((t) => t.id), isNot(contains('del')));
    });

    test('does not affect other rows', () async {
      await repo
          .createTransaction(_tx(id: 'keep', amount: 20, type: TransactionType.income));
      await repo
          .createTransaction(_tx(id: 'gone', amount: 10, type: TransactionType.expense));

      await repo.deleteTransaction('gone');

      final all = await repo.getAllForUser();
      expect(all.map((t) => t.id), contains('keep'));
    });
  });

  // ── getSummary ─────────────────────────────────────────────────────────────

  group('getSummary', () {
    test('returns correct income and expense totals', () async {
      await repo.createTransaction(
          _tx(id: 's1', amount: 100, type: TransactionType.income,
              date: DateTime(2024, 3, 10)));
      await repo.createTransaction(
          _tx(id: 's2', amount: 40, type: TransactionType.expense,
              date: DateTime(2024, 3, 12)));
      await repo.createTransaction(
          _tx(id: 's3', amount: 60, type: TransactionType.income,
              date: DateTime(2024, 3, 15)));

      final summary = await repo.getSummary(
        from: DateTime(2024, 3, 1),
        to: DateTime(2024, 3, 31),
      );

      expect(summary.income, 160.0);
      expect(summary.expense, 40.0);
      expect(summary.balance, 120.0);
    });

    test('returns zero totals when no transactions in range', () async {
      final summary = await repo.getSummary(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 31),
      );
      expect(summary.income, 0.0);
      expect(summary.expense, 0.0);
      expect(summary.balance, 0.0);
    });
  });

  // ── Bulk helpers ───────────────────────────────────────────────────────────

  group('getAllForUser', () {
    test('returns all transactions for the user regardless of date', () async {
      await repo.createTransaction(
          _tx(id: 'a1', amount: 10, type: TransactionType.income,
              date: DateTime(2020, 1, 1)));
      await repo.createTransaction(
          _tx(id: 'a2', amount: 20, type: TransactionType.expense,
              date: DateTime(2023, 6, 15)));

      final all = await repo.getAllForUser();
      expect(all.length, 2);
    });

    test('does not include rows from other users', () async {
      final other = LocalTransactionsRepository(userId: 'stranger');
      await other.createTransaction(
          _tx(id: 'foreign', amount: 999, type: TransactionType.income,
              userId: 'stranger'));

      final all = await repo.getAllForUser();
      expect(all.map((t) => t.id), isNot(contains('foreign')));
    });
  });

  group('insertAll', () {
    test('inserts a batch of transactions', () async {
      final batch = [
        _tx(id: 'b1', amount: 10, type: TransactionType.income),
        _tx(id: 'b2', amount: 20, type: TransactionType.expense),
        _tx(id: 'b3', amount: 30, type: TransactionType.income),
      ];
      await repo.insertAll(batch);

      final all = await repo.getAllForUser();
      expect(all.length, 3);
    });

    test('is idempotent when called twice with the same data', () async {
      final batch = [_tx(id: 'idem', amount: 50, type: TransactionType.income)];
      await repo.insertAll(batch);
      await repo.insertAll(batch);

      final all = await repo.getAllForUser();
      expect(all.where((t) => t.id == 'idem').length, 1);
    });
  });

  group('clearAllForUser', () {
    test('removes all transactions for the user', () async {
      await repo.createTransaction(
          _tx(id: 'c1', amount: 10, type: TransactionType.income));
      await repo.createTransaction(
          _tx(id: 'c2', amount: 20, type: TransactionType.expense));

      await repo.clearAllForUser();

      expect(await repo.getAllForUser(), isEmpty);
    });

    test('does not remove rows for other users', () async {
      final other = LocalTransactionsRepository(userId: 'user-9');
      await other.createTransaction(
          _tx(id: 'safe', amount: 77, type: TransactionType.income,
              userId: 'user-9'));

      await repo.clearAllForUser();

      final otherAll = await other.getAllForUser();
      expect(otherAll.map((t) => t.id), contains('safe'));
    });
  });
}
