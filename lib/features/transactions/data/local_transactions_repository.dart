import 'package:sqflite/sqflite.dart';

import '../../../core/errors/failures.dart';
import '../../../core/local_db/local_database.dart';
import '../../../core/utils/date_helpers.dart';
import '../domain/transaction_model.dart';
import '../domain/transactions_repository_contract.dart';

class LocalTransactionsRepository implements TransactionsRepositoryContract {
  LocalTransactionsRepository({required this.userId});
  final String userId;

  Future<Database> get _db => LocalDatabase.instance.db;

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'transactions',
        where: 'user_id = ? AND date >= ? AND date <= ?',
        whereArgs: [userId, dateToString(from), dateToString(to)],
        orderBy: 'date DESC, created_at DESC',
      );
      return rows.map(_fromRow).toList();
    } catch (_) {
      throw const CacheFailure('Failed to load transactions from local DB');
    }
  }

  @override
  Future<TransactionsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final transactions = await getTransactions(from: from, to: to);
    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.type.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return TransactionsSummary(income: income, expense: expense);
  }

  @override
  Future<TransactionModel> createTransaction(TransactionModel transaction) async {
    try {
      final db = await _db;
      final id = transaction.id.isNotEmpty
          ? transaction.id
          : '${DateTime.now().microsecondsSinceEpoch}_${userId.length >= 8 ? userId.substring(0, 8) : userId}';
      final model = transaction.copyWith(
        id: id,
        userId: userId,
        createdAt: DateTime.now(),
      );
      await db.insert(
        'transactions',
        _toRow(model),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return model;
    } catch (_) {
      throw const CacheFailure('Failed to save transaction');
    }
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) async {
    try {
      final db = await _db;
      await db.update(
        'transactions',
        _toRow(transaction),
        where: 'id = ? AND user_id = ?',
        whereArgs: [transaction.id, userId],
      );
      return transaction;
    } catch (_) {
      throw const CacheFailure('Failed to update transaction');
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      final db = await _db;
      await db.delete(
        'transactions',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
    } catch (_) {
      throw const CacheFailure('Failed to delete transaction');
    }
  }

  // ── Bulk helpers used by TransactionSyncService ──────────────────────────

  Future<List<TransactionModel>> getAllForUser() async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> insertAll(List<TransactionModel> transactions) async {
    final db = await _db;
    final batch = db.batch();
    for (final t in transactions) {
      batch.insert(
        'transactions',
        _toRow(t),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearAllForUser() async {
    final db = await _db;
    await db.delete(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(TransactionModel t) => {
        'id': t.id,
        'user_id': t.userId,
        'amount': t.amount,
        'type': t.type.name,
        'category': t.category,
        'subcategory': t.subcategory,
        'description': t.description,
        'date': dateToString(t.date),
        'created_at': t.createdAt.toIso8601String(),
        'recurring_transaction_id': t.recurringTransactionId,
        'currency': t.currency,
      };

  TransactionModel _fromRow(Map<String, dynamic> row) => TransactionModel(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        amount: (row['amount'] as num).toDouble(),
        type: TransactionType.values.byName(row['type'] as String),
        category: row['category'] as String,
        subcategory: row['subcategory'] as String?,
        description: row['description'] as String?,
        date: DateTime.parse(row['date'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        recurringTransactionId: row['recurring_transaction_id'] as String?,
        currency: row['currency'] as String? ?? 'EUR',
      );
}
