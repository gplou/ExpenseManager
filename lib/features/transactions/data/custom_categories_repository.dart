import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/transaction_categories.dart';
import '../domain/transaction_model.dart';

class CustomCategoriesRepository {
  CustomCategoriesRepository(this._client);
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  Future<List<TransactionCategory>> getByType(TransactionType type) async {
    final response = await _client
        .from('custom_categories')
        .select()
        .eq('user_id', _userId)
        .eq('type', type.name)
        .order('created_at');
    return (response as List).map((e) {
      final cp = e['icon_code'] as int;
      final icon = TransactionCategories.pickableIcons.firstWhere(
        (i) => i.codePoint == cp,
        orElse: () => Icons.label_outlined,
      );
      return TransactionCategory(name: e['name'] as String, icon: icon);
    }).toList();
  }

  Future<void> add(TransactionType type, TransactionCategory cat) async {
    await _client.from('custom_categories').insert({
      'user_id': _userId,
      'name': cat.name,
      'type': type.name,
      'icon_code': cat.icon.codePoint,
    });
  }

  Future<void> remove(TransactionType type, String name) async {
    await _client
        .from('custom_categories')
        .delete()
        .eq('user_id', _userId)
        .eq('type', type.name)
        .eq('name', name);
  }
}

final customCategoriesRepositoryProvider =
    Provider<CustomCategoriesRepository>((ref) {
  return CustomCategoriesRepository(ref.watch(supabaseClientProvider));
});
