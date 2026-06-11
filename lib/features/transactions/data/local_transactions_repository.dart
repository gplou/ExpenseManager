import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/core/utils/date_helpers.dart';
import 'package:expense_manager/core/utils/transaction_id_generator.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/core/utils/app_logger.dart';

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
    } catch (e, st) {
      AppLogger.log('LocalTransactionsRepository.getTransactions error: $e\n$st');
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
          : TransactionIdGenerator.generate(userId);
      final model = transaction.copyWith(
        id: id,
        userId: userId,
        createdAt: clock.now(),
      );
      await db.insert(
        'transactions',
        _toRow(model),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return model;
    } catch (e, st) {
      AppLogger.log('LocalTransactionsRepository.createTransaction error: $e\n$st');
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
    } catch (e, st) {
      AppLogger.log('LocalTransactionsRepository.updateTransaction error: $e\n$st');
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
    } catch (e, st) {
      AppLogger.log('LocalTransactionsRepository.deleteTransaction error: $e\n$st');
      throw const CacheFailure('Failed to delete transaction');
    }
  }

  @override
  Future<void> upsertTransaction(TransactionModel transaction) async {
    try {
      final db = await _db;
      await db.insert(
        'transactions',
        _toRow(transaction),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      AppLogger.log('LocalTransactionsRepository.upsertTransaction error: $e\n$st');
      throw const CacheFailure('Failed to upsert transaction');
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

  /// Elimina las transacciones del usuario dentro de un rango de fechas.
  /// Se usa para sincronizar la caché local con los datos frescos de Supabase
  /// (gestiona correctamente los registros eliminados en la nube).
  Future<void> deleteByDateRange(DateTime from, DateTime to) async {
    final db = await _db;
    await db.delete(
      'transactions',
      where: 'user_id = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, dateToString(from), dateToString(to)],
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

// ── Provider ─────────────────────────────────────────────────────────────────

/// Instancia ligada al usuario autenticado actual.
///
/// Lanza [StateError] si se lee sin sesión: todos los call-sites comprueban
/// `currentUserProvider != null` antes de leerlo. Permite a los tests hacer
/// override sin montar SQLite real.
final localTransactionsRepositoryProvider =
    Provider<LocalTransactionsRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError(
      'localTransactionsRepositoryProvider leído sin usuario autenticado',
    );
  }
  return LocalTransactionsRepository(userId: user.id);
});
