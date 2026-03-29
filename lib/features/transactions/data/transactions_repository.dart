import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/authenticated_repository.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/date_helpers.dart';
import '../domain/transaction_model.dart';
import '../domain/transactions_repository_contract.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../subscription/subscription_provider.dart';
import '../presentation/providers/sync_provider.dart';
import 'local_transactions_repository.dart';

class TransactionsRepository
    with AuthenticatedRepository
    implements TransactionsRepositoryContract {
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
      throw const NetworkFailure('Failed to load transactions');
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
      throw const NetworkFailure('Failed to save transaction');
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
      throw const NetworkFailure('Failed to update transaction');
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
      throw const NetworkFailure('Failed to delete transaction');
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

// ── Provider ─────────────────────────────────────────────────────────────────

final transactionsRepositoryProvider =
    Provider<TransactionsRepositoryContract>((ref) {
  final isPro = ref.watch(isProProvider);
  final user = ref.watch(currentUserProvider);
  final isSyncing = ref.watch(syncProvider).valueOrNull?.isSyncing ?? false;

  // Use Supabase when: PRO, not authenticated, or migration in progress
  // (keep cloud alive during PRO→free download so the user never sees an empty list)
  if (isPro || user == null || isSyncing) {
    return TransactionsRepository(ref.watch(supabaseClientProvider));
  }
  return LocalTransactionsRepository(userId: user.id);
});
