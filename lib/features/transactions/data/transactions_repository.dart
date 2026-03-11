import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/transaction_model.dart';
import '../domain/transactions_repository_contract.dart';

class TransactionsRepository implements TransactionsRepositoryContract {
  final SupabaseClient _client;

  TransactionsRepository(this._client);

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', _client.auth.currentUser!.id)
          .gte('date', _dateString(from))
          .lte('date', _dateString(to))
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => _fromRow(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw const NetworkFailure('No se pudieron cargar las transacciones');
    }
  }

  @override
  Future<TransactionModel> createTransaction(TransactionModel transaction) async {
    try {
      final data = {
        'user_id': _client.auth.currentUser!.id,
        'amount': transaction.amount,
        'type': transaction.type.name,
        'category': transaction.category,
        'subcategory': transaction.subcategory,
        'description': transaction.description,
        'date': _dateString(transaction.date),
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
      throw const NetworkFailure('No se pudo guardar la transacción');
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
        'date': _dateString(transaction.date),
        'recurring_transaction_id': transaction.recurringTransactionId,
      };
      final response = await _client
          .from('transactions')
          .update(data)
          .eq('id', transaction.id)
          .select()
          .single();
      return _fromRow(response);
    } catch (e) {
      throw const NetworkFailure('No se pudo actualizar la transacción');
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await _client.from('transactions').delete().eq('id', id);
    } catch (e) {
      throw const NetworkFailure('No se pudo eliminar la transacción');
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

  String _dateString(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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
      );
}

// ── Provider ─────────────────────────────────────────────────────────────────

final transactionsRepositoryProvider =
    Provider<TransactionsRepositoryContract>((ref) {
  return TransactionsRepository(ref.watch(supabaseClientProvider));
});
