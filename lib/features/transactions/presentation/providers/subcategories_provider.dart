import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subcategories_repository.dart';
import '../../domain/transaction_model.dart';

/// Family provider keyed by (category, type).
/// Returns the list of subcategory names for that category.
final subcategoriesProvider = FutureProvider.autoDispose
    .family<List<String>, ({String category, TransactionType type})>(
  (ref, params) {
    final repo = ref.watch(subcategoriesRepositoryProvider);
    return repo.getForCategory(params.category, params.type);
  },
);
