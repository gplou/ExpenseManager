import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/core/utils/app_logger.dart';
import 'package:expense_manager/core/utils/transaction_id_generator.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/budgets/domain/budgets_repository_contract.dart';

class LocalBudgetsRepository implements BudgetsRepositoryContract {
  LocalBudgetsRepository({required this.userId});
  final String userId;

  Future<Database> get _db => LocalDatabase.instance.db;

  @override
  Future<List<BudgetModel>> getBudgets() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'budgets',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'category ASC',
      );
      return rows.map(_fromRow).toList();
    } catch (e, st) {
      AppLogger.log('LocalBudgetsRepository.getBudgets error: $e\n$st');
      throw const CacheFailure('Failed to load budgets from local DB');
    }
  }

  @override
  Future<BudgetModel> createBudget(BudgetModel budget) async {
    try {
      final db = await _db;
      final model = budget.copyWith(
        id: budget.id.isNotEmpty
            ? budget.id
            : TransactionIdGenerator.generate(userId),
        userId: userId,
        createdAt: clock.now(),
      );
      await db.insert(
        'budgets',
        _toRow(model),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return model;
    } catch (e, st) {
      AppLogger.log('LocalBudgetsRepository.createBudget error: $e\n$st');
      throw const CacheFailure('Failed to save budget');
    }
  }

  @override
  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    try {
      final db = await _db;
      await db.update(
        'budgets',
        _toRow(budget),
        where: 'id = ? AND user_id = ?',
        whereArgs: [budget.id, userId],
      );
      return budget;
    } catch (e, st) {
      AppLogger.log('LocalBudgetsRepository.updateBudget error: $e\n$st');
      throw const CacheFailure('Failed to update budget');
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    try {
      final db = await _db;
      await db.delete(
        'budgets',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
    } catch (e, st) {
      AppLogger.log('LocalBudgetsRepository.deleteBudget error: $e\n$st');
      throw const CacheFailure('Failed to delete budget');
    }
  }

  // ── Espejo local para PRO (MirroredBudgetsRepository) ─────────────────────

  /// Reemplaza el espejo completo con los datos frescos del cloud.
  Future<void> replaceAll(List<BudgetModel> budgets) async {
    final db = await _db;
    final batch = db.batch();
    batch.delete('budgets', where: 'user_id = ?', whereArgs: [userId]);
    for (final b in budgets) {
      batch.insert(
        'budgets',
        _toRow(b),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertBudget(BudgetModel budget) async {
    final db = await _db;
    await db.insert(
      'budgets',
      _toRow(budget),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Migración FREE↔PRO (BudgetsSyncService) ───────────────────────────────

  /// Todos los presupuestos del usuario (alias de [getBudgets] para paralelismo
  /// con las repos de transacciones).
  Future<List<BudgetModel>> getAllForUser() => getBudgets();

  /// Inserta una lista de presupuestos (download cloud→local). Idempotente:
  /// `ConflictAlgorithm.replace` evita duplicados al reintentar.
  Future<void> insertAll(List<BudgetModel> budgets) async {
    final db = await _db;
    final batch = db.batch();
    for (final b in budgets) {
      batch.insert(
        'budgets',
        _toRow(b),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Borra todos los presupuestos locales del usuario (tras subir a la nube en
  /// FREE→PRO, el espejo se rehidrata desde el cloud).
  Future<void> clearAllForUser() async {
    final db = await _db;
    await db.delete('budgets', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(BudgetModel b) => {
        'id': b.id,
        'user_id': b.userId,
        'category': b.category,
        'amount': b.amount,
        'period': b.period,
        'currency': b.currency,
        'created_at': b.createdAt.toIso8601String(),
      };

  BudgetModel _fromRow(Map<String, dynamic> row) => BudgetModel(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        category: row['category'] as String,
        amount: (row['amount'] as num).toDouble(),
        period: row['period'] as String? ?? 'monthly',
        currency: row['currency'] as String? ?? 'EUR',
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

// ── Provider ─────────────────────────────────────────────────────────────────

/// Instancia ligada al usuario autenticado actual.
///
/// Lanza [StateError] si se lee sin sesión, igual que
/// `localTransactionsRepositoryProvider` — los call-sites comprueban
/// `currentUserProvider != null` antes de leerlo.
final localBudgetsRepositoryProvider = Provider<LocalBudgetsRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError(
      'localBudgetsRepositoryProvider leído sin usuario autenticado',
    );
  }
  return LocalBudgetsRepository(userId: user.id);
});
