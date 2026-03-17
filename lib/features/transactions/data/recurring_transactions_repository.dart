import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/utils/date_helpers.dart';
import '../domain/recurring_transaction_model.dart';
import '../domain/transaction_model.dart';

class RecurringTransactionsRepository {
  RecurringTransactionsRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  /// Devuelve las recurrentes cuya [next_occurrence] ya ha llegado.
  Future<List<RecurringTransactionModel>> getDueRecurring() async {
    final today = dateToString(DateTime.now());
    final response = await _client
        .from('recurring_transactions')
        .select()
        .eq('user_id', _userId)
        .lte('next_occurrence', today);
    return (response as List)
        .map((e) =>
            RecurringTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createRecurring({
    required double amount,
    required TransactionType type,
    required String category,
    String? subcategory,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  }) async {
    final response = await _client
        .from('recurring_transactions')
        .insert({
          'user_id': _userId,
          'amount': amount,
          'type': type.name,
          'category': category,
          'subcategory': subcategory,
          'description': description,
          'recurrence_type': recurrenceType.name,
          'next_occurrence': dateToString(nextOccurrence),
        })
        .select('id')
        .single();
    return response['id'] as String;
  }

  Future<RecurringTransactionModel?> getById(String id) async {
    final response = await _client
        .from('recurring_transactions')
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();
    if (response == null) return null;
    return RecurringTransactionModel.fromJson(response);
  }

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
    await _client
        .from('recurring_transactions')
        .update({
          'amount': amount,
          'type': type.name,
          'category': category,
          'subcategory': subcategory,
          'description': description,
          'recurrence_type': recurrenceType.name,
          'next_occurrence': dateToString(nextOccurrence),
        })
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> updateNextOccurrence(String id, DateTime next) async {
    await _client
        .from('recurring_transactions')
        .update({'next_occurrence': dateToString(next)})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> deleteRecurring(String id) async {
    try {
      await _client
          .from('transactions')
          .update({'recurring_transaction_id': null})
          .eq('recurring_transaction_id', id)
          .eq('user_id', _userId);
    } catch (_) {}
    await _client
        .from('recurring_transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }
}

final recurringTransactionsRepositoryProvider =
    Provider<RecurringTransactionsRepository>((ref) {
  return RecurringTransactionsRepository(ref.watch(supabaseClientProvider));
});
