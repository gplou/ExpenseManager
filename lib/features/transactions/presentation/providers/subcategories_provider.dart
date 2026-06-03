import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

/// Family provider keyed by (category, type).
/// Returns the list of subcategory names for that category.
final subcategoriesProvider = FutureProvider.autoDispose
    .family<List<String>, ({String category, TransactionType type})>(
  (ref, params) {
    final repo = ref.watch(subcategoriesRepositoryProvider);
    return repo.getForCategory(params.category, params.type);
  },
);

/// All user subcategories as `[{category, type, name}]`, fetched once and
/// cached for the lifetime of the provider. Invalidate after add/remove.
final allSubcategoriesProvider =
    FutureProvider<List<Map<String, String>>>((ref) {
  final repo = ref.watch(subcategoriesRepositoryProvider);
  return repo.getAll();
});
