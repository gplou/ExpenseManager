import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';

class CustomCategoriesNotifier
    extends Notifier<Map<TransactionType, List<TransactionCategory>>> {
  static const _incomeKey = 'custom_categories_income';
  static const _expenseKey = 'custom_categories_expense';

  @override
  Map<TransactionType, List<TransactionCategory>> build() {
    _load();
    return {
      TransactionType.income: [],
      TransactionType.expense: [],
    };
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      TransactionType.income: _decode(prefs.getString(_incomeKey)),
      TransactionType.expense: _decode(prefs.getString(_expenseKey)),
    };
  }

  List<TransactionCategory> _decode(String? raw) {
    if (raw == null) return [];
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

  Future<void> _persist(
      TransactionType type, List<TransactionCategory> cats) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type.isIncome ? _incomeKey : _expenseKey;
    final encoded = jsonEncode(
      cats.map((c) => {'name': c.name, 'codePoint': c.icon.codePoint}).toList(),
    );
    await prefs.setString(key, encoded);
  }

  Future<void> add(TransactionType type, TransactionCategory cat) async {
    final updated = {
      ...state,
      type: [...state[type]!, cat],
    };
    state = updated;
    await _persist(type, updated[type]!);
  }

  Future<void> remove(TransactionType type, String name) async {
    final updated = {
      ...state,
      type: state[type]!.where((c) => c.name != name).toList(),
    };
    state = updated;
    await _persist(type, updated[type]!);
  }
}

final customCategoriesProvider = NotifierProvider<CustomCategoriesNotifier,
    Map<TransactionType, List<TransactionCategory>>>(
  CustomCategoriesNotifier.new,
);
