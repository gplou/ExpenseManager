import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/network/authenticated_repository.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/core/utils/app_logger.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/budgets/domain/budgets_repository_contract.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'local_budgets_repository.dart';

// ── Supabase (cloud) ─────────────────────────────────────────────────────────

class SupabaseBudgetsRepository
    with AuthenticatedRepository
    implements BudgetsRepositoryContract, CloudBudgetsRepo {
  SupabaseBudgetsRepository(this._client);
  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  @override
  Future<List<BudgetModel>> getBudgets() async {
    try {
      final response = await _client
          .from('budgets')
          .select()
          .eq('user_id', userId)
          .order('category', ascending: true);
      return (response as List)
          .map((e) => _fromRow(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _mapToFailure(e);
    }
  }

  @override
  Future<BudgetModel> createBudget(BudgetModel budget) async {
    try {
      final data = {
        'user_id': userId,
        'category': budget.category,
        'amount': budget.amount,
        'period': budget.period,
        'currency': budget.currency,
      };
      final response =
          await _client.from('budgets').insert(data).select().single();
      return _fromRow(response);
    } catch (e) {
      _mapToFailure(e);
    }
  }

  /// Sube un presupuesto a la nube de forma **aditiva**, preservando su id
  /// (UUID local) para que el id mostrado en la UI no cambie tras la migración
  /// FREE→PRO. El conflicto se resuelve sobre la clave natural
  /// `(user_id, category)`: si la categoría ya tiene presupuesto en la nube se
  /// actualiza en lugar de fallar por la restricción UNIQUE.
  ///
  /// Usado por [BudgetsSyncService.migrateToCloud]; no forma parte del CRUD
  /// normal (los `create`/`update` de la UI pasan por los métodos de arriba).
  @override
  Future<BudgetModel> upsertBudget(BudgetModel budget) async {
    try {
      final data = {
        'id': budget.id,
        'user_id': userId,
        'category': budget.category,
        'amount': budget.amount,
        'period': budget.period,
        'currency': budget.currency,
      };
      final response = await _client
          .from('budgets')
          .upsert(data, onConflict: 'user_id,category')
          .select()
          .single();
      return _fromRow(response);
    } catch (e) {
      _mapToFailure(e);
    }
  }

  /// Lee todos los presupuestos del usuario (alias semántico de [getBudgets]
  /// para uso en migraciones, en paralelo a `getAllForUser` de transacciones).
  @override
  Future<List<BudgetModel>> getAllForUser() => getBudgets();

  @override
  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    try {
      final data = {
        'category': budget.category,
        'amount': budget.amount,
        'currency': budget.currency,
      };
      final response = await _client
          .from('budgets')
          .update(data)
          .eq('id', budget.id)
          .eq('user_id', userId)
          .select()
          .single();
      return _fromRow(response);
    } catch (e) {
      _mapToFailure(e);
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    try {
      await _client.from('budgets').delete().eq('id', id).eq('user_id', userId);
    } catch (e) {
      _mapToFailure(e);
    }
  }

  BudgetModel _fromRow(Map<String, dynamic> row) => BudgetModel(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        category: row['category'] as String,
        amount: (row['amount'] as num).toDouble(),
        period: row['period'] as String? ?? 'monthly',
        currency: row['currency'] as String? ?? 'EUR',
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  Never _mapToFailure(Object e) {
    if (e is AppFailure) throw e;
    if (e is AuthException) throw const AuthFailure('Auth session expired');
    if (e is PostgrestException) throw NetworkFailure(e.message);
    throw const NetworkFailure('Network request failed');
  }
}

// ── Cloud-first con espejo local (PRO) ───────────────────────────────────────

/// Escrituras: cloud primero (si falla, falla la acción — CRUD de baja
/// frecuencia, sin cola de sync en v1) y espejo local best-effort.
/// Lecturas: cloud con fallback al espejo SQLite si no hay red.
class MirroredBudgetsRepository implements BudgetsRepositoryContract {
  MirroredBudgetsRepository({required this.cloud, required this.local});

  final SupabaseBudgetsRepository cloud;
  final LocalBudgetsRepository local;

  @override
  Future<List<BudgetModel>> getBudgets() async {
    try {
      final fresh = await cloud.getBudgets();
      try {
        await local.replaceAll(fresh);
      } catch (e) {
        AppLogger.log('MirroredBudgets: mirror write failed: $e');
      }
      return fresh;
    } on AuthFailure {
      rethrow;
    } on AppFailure {
      // Sin red: servimos el espejo local.
      return local.getBudgets();
    }
  }

  @override
  Future<BudgetModel> createBudget(BudgetModel budget) async {
    final created = await cloud.createBudget(budget);
    try {
      await local.upsertBudget(created);
    } catch (e) {
      AppLogger.log('MirroredBudgets: mirror upsert failed: $e');
    }
    return created;
  }

  @override
  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    final updated = await cloud.updateBudget(budget);
    try {
      await local.upsertBudget(updated);
    } catch (e) {
      AppLogger.log('MirroredBudgets: mirror upsert failed: $e');
    }
    return updated;
  }

  @override
  Future<void> deleteBudget(String id) async {
    await cloud.deleteBudget(id);
    try {
      await local.deleteBudget(id);
    } catch (e) {
      AppLogger.log('MirroredBudgets: mirror delete failed: $e');
    }
  }
}

// ── Selección FREE/PRO ───────────────────────────────────────────────────────

/// FREE → SQLite local únicamente. PRO → cloud-first con espejo local.
/// Mismo criterio que `transactionsRepositoryProvider`: mientras la
/// suscripción carga usamos el camino PRO para no perder escrituras cloud.
final budgetsRepositoryProvider = Provider<BudgetsRepositoryContract>((ref) {
  final isPro = ref.watch(isProProvider);
  final user = ref.watch(currentUserProvider);
  final subscriptionLoaded = ref.watch(
    subscriptionProvider.select((s) => s.hasValue),
  );

  if (user == null) {
    // Sin sesión no hay presupuestos; el cloud repo lanzará AuthFailure si se
    // usa. No instanciamos el local (requiere userId).
    return SupabaseBudgetsRepository(ref.watch(supabaseClientProvider));
  }

  if (isPro || !subscriptionLoaded) {
    return MirroredBudgetsRepository(
      cloud: SupabaseBudgetsRepository(ref.watch(supabaseClientProvider)),
      local: ref.watch(localBudgetsRepositoryProvider),
    );
  }

  return ref.watch(localBudgetsRepositoryProvider);
});
