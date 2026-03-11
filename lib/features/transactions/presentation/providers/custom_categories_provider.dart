import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/custom_categories_repository.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';

class CustomCategoriesNotifier extends AsyncNotifier<
    Map<TransactionType, List<TransactionCategory>>> {
  static const _incomeKey = 'custom_categories_income';
  static const _expenseKey = 'custom_categories_expense';
  static const _migratedKey = 'custom_categories_migrated';

  @override
  Future<Map<TransactionType, List<TransactionCategory>>> build() async {
    final repo = ref.watch(customCategoriesRepositoryProvider);

    // One-time migration: SharedPreferences → Supabase
    await _migrateIfNeeded(repo);

    final income = await repo.getByType(TransactionType.income);
    final expense = await repo.getByType(TransactionType.expense);
    return {
      TransactionType.income: income,
      TransactionType.expense: expense,
    };
  }

  Future<void> _migrateIfNeeded(CustomCategoriesRepository repo) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    for (final type in TransactionType.values) {
      final key = type.isIncome ? _incomeKey : _expenseKey;
      final raw = prefs.getString(key);
      if (raw == null) continue;

      final cats = _decodeOldFormat(raw);
      for (final cat in cats) {
        try {
          await repo.add(type, cat);
        } catch (_) {
          // UNIQUE constraint → already exists, skip
        }
      }
      await prefs.remove(key);
    }
    await prefs.setBool(_migratedKey, true);
  }

  List<TransactionCategory> _decodeOldFormat(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final cp = e['codePoint'] as int;
        final icon = TransactionCategories.pickableIcons.firstWhere(
          (i) => i.codePoint == cp,
          orElse: () => Icons.label_outlined,
        );
        return TransactionCategory(name: e['name'] as String, icon: icon);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(TransactionType type, TransactionCategory cat) async {
    final repo = ref.read(customCategoriesRepositoryProvider);
    await repo.add(type, cat);
    ref.invalidateSelf();
  }

  Future<void> remove(TransactionType type, String name) async {
    final repo = ref.read(customCategoriesRepositoryProvider);
    await repo.remove(type, name);
    ref.invalidateSelf();
  }
}

final customCategoriesProvider = AsyncNotifierProvider<
    CustomCategoriesNotifier,
    Map<TransactionType, List<TransactionCategory>>>(
  CustomCategoriesNotifier.new,
);

/// Convenience synchronous provider — returns empty map while loading.
/// Minimizes UI changes: existing ref.watch calls just swap provider name.
final customCategoriesSyncProvider =
    Provider<Map<TransactionType, List<TransactionCategory>>>((ref) {
  return ref.watch(customCategoriesProvider).valueOrNull ??
      {
        TransactionType.income: [],
        TransactionType.expense: [],
      };
});
