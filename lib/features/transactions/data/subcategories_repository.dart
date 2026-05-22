import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/authenticated_repository.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/transaction_model.dart';

class SubcategoriesRepository with AuthenticatedRepository {
  SubcategoriesRepository(this._client);
  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  Future<List<String>> getForCategory(
      String category, TransactionType type) async {
    final response = await _client
        .from('subcategories')
        .select('name')
        .eq('user_id', userId)
        .eq('category', category)
        .eq('type', type.name)
        .order('created_at');
    return (response as List).map((e) => e['name'] as String).toList();
  }

  Future<void> add(
      String category, TransactionType type, String name) async {
    await _client.from('subcategories').insert({
      'user_id': userId,
      'category': category,
      'type': type.name,
      'name': name,
    });
  }

  Future<void> remove(
      String category, TransactionType type, String name) async {
    await _client
        .from('subcategories')
        .delete()
        .eq('user_id', userId)
        .eq('category', category)
        .eq('type', type.name)
        .eq('name', name);
  }
}

final subcategoriesRepositoryProvider =
    Provider<SubcategoriesRepository>((ref) {
  return SubcategoriesRepository(ref.watch(supabaseClientProvider));
});
