import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/recurring_transaction_model.dart';
import '../domain/transaction_model.dart';

class RecurringTransactionsRepository {
  RecurringTransactionsRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Devuelve las recurrentes cuya [next_occurrence] ya ha llegado.
  Future<List<RecurringTransactionModel>> getDueRecurring() async {
    final today = _dateStr(DateTime.now());
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

  Future<void> createRecurring({
    required double amount,
    required TransactionType type,
    required String category,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  }) async {
    await _client.from('recurring_transactions').insert({
      'user_id': _userId,
      'amount': amount,
      'type': type.name,
      'category': category,
      'description': description,
      'recurrence_type': recurrenceType.name,
      'next_occurrence': _dateStr(nextOccurrence),
    });
  }

  Future<void> updateNextOccurrence(String id, DateTime next) async {
    await _client
        .from('recurring_transactions')
        .update({'next_occurrence': _dateStr(next)})
        .eq('id', id);
  }

  Future<void> deleteRecurring(String id) async {
    await _client.from('recurring_transactions').delete().eq('id', id);
  }
}

final recurringTransactionsRepositoryProvider =
    Provider<RecurringTransactionsRepository>((ref) {
  return RecurringTransactionsRepository(ref.watch(supabaseClientProvider));
});
