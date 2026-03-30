import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/authenticated_repository.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/date_helpers.dart';
import '../domain/recurring_transaction_model.dart';
import '../domain/recurring_transactions_repository_contract.dart';
import '../domain/transaction_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../subscription/subscription_provider.dart';
import '../presentation/providers/sync_provider.dart';
import 'local_recurring_transactions_repository.dart';

class RecurringTransactionsRepository
    with AuthenticatedRepository
    implements RecurringTransactionsRepositoryContract {
  RecurringTransactionsRepository(this._client);
  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  /// Devuelve las recurrentes cuya [next_occurrence] ya ha llegado.
  @override
  Future<List<RecurringTransactionModel>> getDueRecurring() async {
    final today = dateToString(DateTime.now());
    final response = await _client
        .from('recurring_transactions')
        .select()
        .eq('user_id', userId)
        .lte('next_occurrence', today);
    return (response as List)
        .map((e) =>
            RecurringTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
    final response = await _client
        .from('recurring_transactions')
        .insert({
          'user_id': userId,
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

  @override
  Future<RecurringTransactionModel?> getById(String id) async {
    final response = await _client
        .from('recurring_transactions')
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) return null;
    return RecurringTransactionModel.fromJson(response);
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
        .eq('user_id', userId);
  }

  @override
  Future<void> updateNextOccurrence(String id, DateTime next) async {
    await _client
        .from('recurring_transactions')
        .update({'next_occurrence': dateToString(next)})
        .eq('id', id)
        .eq('user_id', userId);
  }

  @override
  Future<void> deleteRecurring(String id) async {
    try {
      await _client
          .from('transactions')
          .update({'recurring_transaction_id': null})
          .eq('recurring_transaction_id', id)
          .eq('user_id', userId);
    } catch (_) {}
    await _client
        .from('recurring_transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  @override
  Future<List<RecurringTransactionModel>> getAllForUser() async {
    final response = await _client
        .from('recurring_transactions')
        .select()
        .eq('user_id', userId);
    return (response as List)
        .map((e) => RecurringTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final recurringTransactionsRepositoryProvider =
    Provider<RecurringTransactionsRepositoryContract>((ref) {
  final isPro = ref.watch(isProProvider);
  final user = ref.watch(currentUserProvider);
  final isSyncing = ref.watch(syncProvider).valueOrNull?.isSyncing ?? false;

  if (isPro || user == null || isSyncing) {
    return RecurringTransactionsRepository(ref.watch(supabaseClientProvider));
  }
  return LocalRecurringTransactionsRepository(userId: user.id);
});
