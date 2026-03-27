import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/authenticated_repository.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/custom_categories_repository_contract.dart';
import '../domain/transaction_categories.dart';
import '../domain/transaction_model.dart';

class CustomCategoriesRepository
    with AuthenticatedRepository
    implements CustomCategoriesRepositoryContract {
  CustomCategoriesRepository(this._client);
  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;

  @override
  Future<List<TransactionCategory>> getByType(TransactionType type) async {
    final response = await _client
        .from('custom_categories')
        .select()
        .eq('user_id', userId)
        .eq('type', type.name)
        .order('created_at');
    return (response as List).map((e) {
      final cp = e['icon_code'] as int;
      // Check if this codePoint belongs to a Material icon (pickableIcons)
      final materialIcon = TransactionCategories.pickableIcons
          .where((i) => i.codePoint == cp)
          .firstOrNull;
      if (materialIcon != null) {
        return TransactionCategory(name: e['name'] as String, icon: materialIcon);
      }
      return TransactionCategory(
        name: e['name'] as String,
        icon: Icons.label_outlined,
        emojiOverride: String.fromCharCode(cp),
      );
    }).toList();
  }

  @override
  Future<void> add(TransactionType type, TransactionCategory cat) async {
    final iconCode = cat.emojiOverride != null
        ? cat.emojiOverride!.runes.first
        : cat.icon.codePoint;
    await _client.from('custom_categories').insert({
      'user_id': userId,
      'name': cat.name,
      'type': type.name,
      'icon_code': iconCode,
    });
  }

  @override
  Future<void> remove(TransactionType type, String name) async {
    await _client
        .from('custom_categories')
        .delete()
        .eq('user_id', userId)
        .eq('type', type.name)
        .eq('name', name);
  }
}

final customCategoriesRepositoryProvider =
    Provider<CustomCategoriesRepositoryContract>((ref) {
  return CustomCategoriesRepository(ref.watch(supabaseClientProvider));
});
