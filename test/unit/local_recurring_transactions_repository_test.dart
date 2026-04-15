import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();

  late LocalRecurringTransactionsRepository repo;

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);
    repo = LocalRecurringTransactionsRepository(userId: 'user-1');
  });

  tearDown(() async {
    await LocalDatabase.instance.close();
  });

  // ── createRecurring ────────────────────────────────────────────────────────

  group('createRecurring', () {
    test('stores a recurring transaction and returns a non-empty id', () async {
      final id = await repo.createRecurring(
        amount: 200,
        type: TransactionType.expense,
        category: 'Comida',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 4, 1),
      );
      expect(id, isNotEmpty);
    });

    test('persists so it appears in getAllForUser', () async {
      await repo.createRecurring(
        amount: 50,
        type: TransactionType.income,
        category: 'Salario',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 4, 15),
      );
      final all = await repo.getAllForUser();
      expect(all.length, 1);
      expect(all.first.amount, 50.0);
    });
  });

  // ── getDueRecurring ────────────────────────────────────────────────────────

  group('getDueRecurring', () {
    test('returns only rows whose next_occurrence is today or earlier', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      await repo.createRecurring(
        amount: 10,
        type: TransactionType.expense,
        category: 'Comida',
        recurrenceType: RecurrenceType.weekly,
        nextOccurrence: yesterday,
      );
      await repo.createRecurring(
        amount: 20,
        type: TransactionType.expense,
        category: 'Transporte',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: tomorrow,
      );

      final due = await repo.getDueRecurring();
      expect(due.length, 1);
      expect(due.first.amount, 10.0);
    });

    test('returns empty list when nothing is due', () async {
      final future = DateTime.now().add(const Duration(days: 30));
      await repo.createRecurring(
        amount: 100,
        type: TransactionType.income,
        category: 'Salario',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: future,
      );
      expect(await repo.getDueRecurring(), isEmpty);
    });
  });

  // ── getById ────────────────────────────────────────────────────────────────

  group('getById', () {
    test('returns the model for a known id', () async {
      final id = await repo.createRecurring(
        amount: 150,
        type: TransactionType.expense,
        category: 'Ocio',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 5, 1),
      );

      final found = await repo.getById(id);
      expect(found, isNotNull);
      expect(found!.amount, 150.0);
      expect(found.category, 'Ocio');
    });

    test('returns null for an unknown id', () async {
      final result = await repo.getById('does-not-exist');
      expect(result, isNull);
    });

    test('does not return rows owned by another user', () async {
      final otherRepo =
          LocalRecurringTransactionsRepository(userId: 'user-2');
      final id = await otherRepo.createRecurring(
        amount: 300,
        type: TransactionType.income,
        category: 'Freelance',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 5, 1),
      );

      final result = await repo.getById(id);
      expect(result, isNull);
    });
  });

  // ── updateRecurring ────────────────────────────────────────────────────────

  group('updateRecurring', () {
    test('updates the amount and category', () async {
      final id = await repo.createRecurring(
        amount: 50,
        type: TransactionType.expense,
        category: 'Comida',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 4, 1),
      );

      await repo.updateRecurring(
        id: id,
        amount: 75,
        type: TransactionType.expense,
        category: 'Ropa',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 4, 1),
      );

      final updated = await repo.getById(id);
      expect(updated!.amount, 75.0);
      expect(updated.category, 'Ropa');
    });
  });

  // ── updateNextOccurrence ───────────────────────────────────────────────────

  group('updateNextOccurrence', () {
    test('advances the next_occurrence date', () async {
      final id = await repo.createRecurring(
        amount: 100,
        type: TransactionType.income,
        category: 'Salario',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 3, 1),
      );

      await repo.updateNextOccurrence(id, DateTime(2024, 4, 1));

      final updated = await repo.getById(id);
      expect(updated!.nextOccurrence, DateTime(2024, 4, 1));
    });
  });

  // ── deleteRecurring ────────────────────────────────────────────────────────

  group('deleteRecurring', () {
    test('removes the recurring row', () async {
      final id = await repo.createRecurring(
        amount: 40,
        type: TransactionType.expense,
        category: 'Suscripción',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 5, 1),
      );

      await repo.deleteRecurring(id);

      expect(await repo.getById(id), isNull);
    });

    test('nullifies recurring_transaction_id in linked local transactions',
        () async {
      final txRepo = LocalTransactionsRepository(userId: 'user-1');

      final recurringId = await repo.createRecurring(
        amount: 30,
        type: TransactionType.expense,
        category: 'Transporte',
        recurrenceType: RecurrenceType.weekly,
        nextOccurrence: DateTime(2024, 4, 1),
      );

      // Create a local transaction linked to this recurring
      await txRepo.createTransaction(TransactionModel(
        id: 'linked-tx',
        userId: 'user-1',
        amount: 30,
        type: TransactionType.expense,
        category: 'Transporte',
        date: DateTime(2024, 4, 1),
        createdAt: DateTime(2024, 4, 1),
        recurringTransactionId: recurringId,
      ));

      await repo.deleteRecurring(recurringId);

      // The transaction should still exist but FK should be null
      final txAll = await txRepo.getAllForUser();
      final linked = txAll.firstWhere((t) => t.id == 'linked-tx');
      expect(linked.recurringTransactionId, isNull);
    });
  });

  // ── Bulk helpers ───────────────────────────────────────────────────────────

  group('insertAll', () {
    test('bulk-inserts a list of models', () async {
      final models = [
        RecurringTransactionModel(
          id: 'r1',
          userId: 'user-1',
          amount: 100,
          type: TransactionType.income,
          category: 'Salario',
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: DateTime(2024, 4, 1),
          createdAt: DateTime(2024, 1, 1),
        ),
        RecurringTransactionModel(
          id: 'r2',
          userId: 'user-1',
          amount: 50,
          type: TransactionType.expense,
          category: 'Comida',
          recurrenceType: RecurrenceType.weekly,
          nextOccurrence: DateTime(2024, 4, 7),
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      await repo.insertAll(models);

      final all = await repo.getAllForUser();
      expect(all.length, 2);
      expect(all.map((r) => r.id), containsAll(['r1', 'r2']));
    });
  });

  // ── upsertRecurring ────────────────────────────────────────────────────────

  group('upsertRecurring', () {
    test('inserts a new recurring transaction when none exists', () async {
      final model = RecurringTransactionModel(
        id: 'rec-new',
        userId: 'user-1',
        amount: 100,
        type: TransactionType.expense,
        category: 'Suscripción',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 6, 1),
        createdAt: DateTime(2024, 1, 1),
      );
      await repo.upsertRecurring(model);

      final all = await repo.getAllForUser();
      expect(all.map((r) => r.id), contains('rec-new'));
      expect(all.firstWhere((r) => r.id == 'rec-new').amount, 100.0);
    });

    test('replaces an existing recurring transaction preserving the id', () async {
      final original = RecurringTransactionModel(
        id: 'rec-exist',
        userId: 'user-1',
        amount: 50,
        type: TransactionType.expense,
        category: 'Comida',
        recurrenceType: RecurrenceType.weekly,
        nextOccurrence: DateTime(2024, 6, 1),
        createdAt: DateTime(2024, 1, 1),
      );
      await repo.insertAll([original]);

      await repo.upsertRecurring(RecurringTransactionModel(
        id: 'rec-exist',
        userId: 'user-1',
        amount: 200,
        type: TransactionType.income,
        category: 'Salario',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 7, 1),
        createdAt: DateTime(2024, 1, 1),
      ));

      final all = await repo.getAllForUser();
      final found = all.where((r) => r.id == 'rec-exist').toList();
      expect(found.length, 1);
      expect(found.first.amount, 200.0);
      expect(found.first.category, 'Salario');
    });
  });

  group('clearAllForUser', () {
    test('removes all recurring rows for the user', () async {
      await repo.createRecurring(
        amount: 10,
        type: TransactionType.expense,
        category: 'Comida',
        recurrenceType: RecurrenceType.weekly,
        nextOccurrence: DateTime(2024, 4, 1),
      );
      await repo.clearAllForUser();
      expect(await repo.getAllForUser(), isEmpty);
    });

    test('does not remove rows for other users', () async {
      final other = LocalRecurringTransactionsRepository(userId: 'user-X');
      await other.createRecurring(
        amount: 999,
        type: TransactionType.income,
        category: 'Freelance',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2024, 5, 1),
      );

      await repo.clearAllForUser();

      final otherAll = await other.getAllForUser();
      expect(otherAll, isNotEmpty);
    });
  });
}
