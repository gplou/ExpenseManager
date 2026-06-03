import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/services/sentry_service.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

class HiddenBuiltInCategoriesNotifier
    extends Notifier<Map<TransactionType, Set<String>>> {
  static const _incomeKey = 'hidden_builtin_income';
  static const _expenseKey = 'hidden_builtin_expense';

  @override
  Map<TransactionType, Set<String>> build() {
    _load();
    return {
      TransactionType.income: {},
      TransactionType.expense: {},
    };
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      TransactionType.income: _decode(prefs.getString(_incomeKey)),
      TransactionType.expense: _decode(prefs.getString(_expenseKey)),
    };
  }

  Set<String> _decode(String? raw) {
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (e) {
      SentryService.addBreadcrumb(
          'hidden categories decode failed: $e', category: 'prefs');
      return {};
    }
  }

  Future<void> _persist(TransactionType type, Set<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type.isIncome ? _incomeKey : _expenseKey;
    await prefs.setString(key, jsonEncode(names.toList()));
  }

  Future<void> hide(TransactionType type, String name) async {
    final updated = {
      ...state,
      type: {...state[type]!, name},
    };
    state = updated;
    await _persist(type, updated[type]!);
  }
}

final hiddenBuiltInCategoriesProvider = NotifierProvider<
    HiddenBuiltInCategoriesNotifier, Map<TransactionType, Set<String>>>(
  HiddenBuiltInCategoriesNotifier.new,
);
