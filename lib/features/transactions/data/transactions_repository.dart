import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/network/authenticated_repository.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/core/utils/date_helpers.dart';
import 'package:expense_manager/features/transactions/domain/cloud_transaction_sync_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/sync_provider.dart';
import 'package:expense_manager/core/utils/app_logger.dart';
import 'local_transactions_repository.dart';
import 'offline_aware_transactions_repository.dart';
import 'sync_queue_repository.dart';

class TransactionsRepository
    with AuthenticatedRepository
    implements TransactionsRepositoryContract, CloudTransactionSyncContract {
  TransactionsRepository(this._client);
  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('date', dateToString(from))
          .lte('date', dateToString(to))
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => _fromRow(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _mapToFailure(e);
    }
  }

  @override
  Future<TransactionModel> createTransaction(TransactionModel transaction) async {
    try {
      final data = {
        'user_id': userId,
        'amount': transaction.amount,
        'type': transaction.type.name,
        'category': transaction.category,
        'subcategory': transaction.subcategory,
        'description': transaction.description,
        'date': dateToString(transaction.date),
        'currency': transaction.currency,
        if (transaction.recurringTransactionId != null)
          'recurring_transaction_id': transaction.recurringTransactionId,
      };
      final response = await _client
          .from('transactions')
          .insert(data)
          .select()
          .single();
      return _fromRow(response);
    } catch (e) {
      _mapToFailure(e);
    }
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) async {
    try {
      final data = {
        'amount': transaction.amount,
        'type': transaction.type.name,
        'category': transaction.category,
        'subcategory': transaction.subcategory,
        'description': transaction.description,
        'date': dateToString(transaction.date),
        'currency': transaction.currency,
        'recurring_transaction_id': transaction.recurringTransactionId,
      };
      final response = await _client
          .from('transactions')
          .update(data)
          .eq('id', transaction.id)
          .eq('user_id', userId)
          .select()
          .single();
      return _fromRow(response);
    } catch (e) {
      _mapToFailure(e);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await _client
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      _mapToFailure(e);
    }
  }

  /// Upsert con ID explícito — usado por el sync offline para subir
  /// transacciones creadas localmente con un ID ya asignado.
  @override
  Future<void> upsertTransaction(TransactionModel transaction) async {
    try {
      final data = {
        'id': transaction.id,
        'user_id': userId,
        'amount': transaction.amount,
        'type': transaction.type.name,
        'category': transaction.category,
        'subcategory': transaction.subcategory,
        'description': transaction.description,
        'date': dateToString(transaction.date),
        'currency': transaction.currency,
        'recurring_transaction_id': transaction.recurringTransactionId,
      };
      await _client.from('transactions').upsert(data, onConflict: 'id');
    } catch (e) {
      _mapToFailure(e);
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

  // ── Helpers ─────────────────────────────────────────────────────────────────

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

// ── Error mapping ────────────────────────────────────────────────────────────

/// Converts Supabase/network exceptions into typed [AppFailure]s.
/// Existing [AppFailure]s (e.g. [AuthFailure] from the [userId] getter) are
/// re-thrown unchanged so they are never silently downgraded to [NetworkFailure].
Never _mapToFailure(Object e) {
  if (e is AppFailure) throw e;
  if (e is AuthException) {
    // Mensajes técnicos (logs/Sentry); la UI localiza por tipo de failure
    // vía failure_localizations.dart.
    throw const AuthFailure('Auth session expired');
  }
  if (e is PostgrestException) {
    throw NetworkFailure(e.message);
  }
  throw const NetworkFailure('Network request failed');
}

// ── Provider ─────────────────────────────────────────────────────────────────

final transactionsRepositoryProvider =
    Provider<TransactionsRepositoryContract>((ref) {
  final isPro = ref.watch(isProProvider);
  final user = ref.watch(currentUserProvider);
  final isSyncing = ref.watch(
    syncProvider.select((s) => s.value?.isSyncing ?? false),
  );
  // True una vez que subscriptionProvider ha resuelto su primer valor.
  final subscriptionLoaded = ref.watch(
    subscriptionProvider.select((s) => s.hasValue),
  );

  // No autenticado o migración en curso → Supabase directo.
  if (user == null || isSyncing) {
    AppLogger.log('transactionsRepo → DirectSupabase (user=${user?.id.substring(0, 8)}, syncing=$isSyncing)');
    return TransactionsRepository(ref.watch(supabaseClientProvider));
  }

  // PRO confirmado, o suscripción todavía cargando.
  // Usamos OfflineAware mientras carga para evitar que transacciones creadas
  // en esa ventana se guarden solo en SQLite sin intentar Supabase.
  // No watchear conectividad aquí: reconstruiría el repo (y recargaría
  // allTransactionsProvider) en cada cambio de red. El fallback offline ya lo
  // resuelve OfflineAwareTransactionsRepository por operación (try cloud →
  // encolar) sin necesitar el estado de conexión.
  if (isPro || !subscriptionLoaded) {
    AppLogger.log('transactionsRepo → OfflineAware (isPro=$isPro, loaded=$subscriptionLoaded)');
    return OfflineAwareTransactionsRepository(
      cloud: TransactionsRepository(ref.watch(supabaseClientProvider)),
      local: ref.watch(localTransactionsRepositoryProvider),
      queue: ref.watch(syncQueueRepositoryProvider),
    );
  }

  // FREE confirmado → SQLite local únicamente.
  AppLogger.log('transactionsRepo → LocalOnly (FREE user, subscription loaded)');
  return ref.watch(localTransactionsRepositoryProvider);
});
