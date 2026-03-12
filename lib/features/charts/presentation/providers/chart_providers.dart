import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/domain/transaction_model.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

// ── Filter state ─────────────────────────────────────────────────────────────

final chartTypeFilterProvider =
    StateProvider<TransactionType>((ref) => TransactionType.expense);

final chartCategoryFilterProvider = StateProvider<String?>((ref) => null);

final chartSubcategoryFilterProvider = StateProvider<String?>((ref) => null);

// ── Chart distribution data ──────────────────────────────────────────────────

final chartDistributionProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final type = ref.watch(chartTypeFilterProvider);
  final category = ref.watch(chartCategoryFilterProvider);
  final transactions = await ref.watch(allTransactionsProvider.future);

  final filtered = transactions.where((t) => t.type == type);
  final map = <String, double>{};

  if (category == null) {
    // Group by category
    for (final t in filtered) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
  } else {
    // Group by subcategory within the selected category
    for (final t in filtered.where((t) => t.category == category)) {
      final key = t.subcategory ?? '_no_subcategory_';
      map[key] = (map[key] ?? 0) + t.amount;
    }
  }

  return map;
});

// ── Filtered total ───────────────────────────────────────────────────────────

final chartFilteredTotalProvider =
    FutureProvider.autoDispose<double>((ref) async {
  final type = ref.watch(chartTypeFilterProvider);
  final category = ref.watch(chartCategoryFilterProvider);
  final subcategory = ref.watch(chartSubcategoryFilterProvider);
  final transactions = await ref.watch(allTransactionsProvider.future);

  var filtered = transactions.where((t) => t.type == type);
  if (category != null) {
    filtered = filtered.where((t) => t.category == category);
  }
  if (subcategory != null) {
    filtered = filtered.where((t) => t.subcategory == subcategory);
  }

  return filtered.fold<double>(0, (sum, t) => sum + t.amount);
});
