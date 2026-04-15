import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/errors/failures.dart';
import '../../../core/local_db/local_database.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/transaction_id_generator.dart';
import '../domain/recurring_transaction_model.dart';
import '../domain/recurring_transactions_repository_contract.dart';
import '../domain/transaction_model.dart';

class LocalRecurringTransactionsRepository
    implements RecurringTransactionsRepositoryContract {
  LocalRecurringTransactionsRepository({required this.userId});
  final String userId;

  Future<Database> get _db => LocalDatabase.instance.db;

  @override
  Future<List<RecurringTransactionModel>> getDueRecurring() async {
    try {
      final db = await _db;
      final today = dateToString(DateTime.now());
      final rows = await db.query(
        'recurring_transactions',
        where: 'user_id = ? AND next_occurrence <= ?',
        whereArgs: [userId, today],
      );
      return rows.map(_fromRow).toList();
    } catch (e, st) {
      debugPrint('LocalRecurringTransactionsRepository.getDueRecurring error: $e\n$st');
      throw const CacheFailure('Failed to load recurring transactions');
    }
  }

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
    try {
      final db = await _db;
      final id = TransactionIdGenerator.generate(userId);
      await db.insert(
        'recurring_transactions',
        {
          'id': id,
          'user_id': userId,
          'amount': amount,
          'type': type.name,
          'category': category,
          'subcategory': subcategory,
          'description': description,
          'recurrence_type': recurrenceType.name,
          'next_occurrence': dateToString(nextOccurrence),
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id;
    } catch (e, st) {
      debugPrint('LocalRecurringTransactionsRepository.createRecurring error: $e\n$st');
      throw const CacheFailure('Failed to save recurring transaction');
    }
  }

  @override
  Future<RecurringTransactionModel?> getById(String id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'recurring_transactions',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _fromRow(rows.first);
    } catch (e, st) {
      debugPrint('LocalRecurringTransactionsRepository.getById error: $e\n$st');
      throw const CacheFailure('Failed to get recurring transaction');
    }
  }

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
  }) async {
    try {
      final db = await _db;
      await db.update(
        'recurring_transactions',
        {
          'amount': amount,
          'type': type.name,
          'category': category,
          'subcategory': subcategory,
          'description': description,
          'recurrence_type': recurrenceType.name,
          'next_occurrence': dateToString(nextOccurrence),
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
    } catch (e, st) {
      debugPrint('LocalRecurringTransactionsRepository.updateRecurring error: $e\n$st');
      throw const CacheFailure('Failed to update recurring transaction');
    }
  }

  @override
  Future<void> updateNextOccurrence(String id, DateTime next) async {
    try {
      final db = await _db;
      await db.update(
        'recurring_transactions',
        {'next_occurrence': dateToString(next)},
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
    } catch (e, st) {
      debugPrint('LocalRecurringTransactionsRepository.updateNextOccurrence error: $e\n$st');
      throw const CacheFailure('Failed to update next occurrence');
    }
  }

  @override
  Future<void> deleteRecurring(String id) async {
    try {
      final db = await _db;
      // Clear FK reference in local transactions table first
      await db.update(
        'transactions',
        {'recurring_transaction_id': null},
        where: 'recurring_transaction_id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
      await db.delete(
        'recurring_transactions',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
    } catch (e, st) {
      debugPrint('LocalRecurringTransactionsRepository.deleteRecurring error: $e\n$st');
      throw const CacheFailure('Failed to delete recurring transaction');
    }
  }

  @override
  Future<void> upsertRecurring(RecurringTransactionModel model) async {
    try {
      final db = await _db;
      await db.insert(
        'recurring_transactions',
        _toRow(model),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      debugPrint(
          'LocalRecurringTransactionsRepository.upsertRecurring error: $e\n$st');
      throw const CacheFailure('Failed to upsert recurring transaction');
    }
  }

  // ── Bulk helpers used by TransactionSyncService ──────────────────────────

  @override
  Future<List<RecurringTransactionModel>> getAllForUser() async {
    final db = await _db;
    final rows = await db.query(
      'recurring_transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> insertAll(List<RecurringTransactionModel> models) async {
    final db = await _db;
    final batch = db.batch();
    for (final m in models) {
      batch.insert(
        'recurring_transactions',
        _toRow(m),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearAllForUser() async {
    final db = await _db;
    await db.delete(
      'recurring_transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(RecurringTransactionModel m) => {
        'id': m.id,
        'user_id': m.userId,
        'amount': m.amount,
        'type': m.type.name,
        'category': m.category,
        'subcategory': m.subcategory,
        'description': m.description,
        'recurrence_type': m.recurrenceType.name,
        'next_occurrence': dateToString(m.nextOccurrence),
        'created_at': m.createdAt.toIso8601String(),
      };

  RecurringTransactionModel _fromRow(Map<String, dynamic> row) =>
      RecurringTransactionModel(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        amount: (row['amount'] as num).toDouble(),
        type: TransactionType.values.byName(row['type'] as String),
        category: row['category'] as String,
        subcategory: row['subcategory'] as String?,
        description: row['description'] as String?,
        recurrenceType:
            RecurrenceType.values.byName(row['recurrence_type'] as String),
        nextOccurrence: DateTime.parse(row['next_occurrence'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
