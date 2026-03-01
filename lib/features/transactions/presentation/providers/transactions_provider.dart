import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/transactions_repository.dart';
import '../../domain/transaction_model.dart';
import '../../domain/transactions_repository_contract.dart';

// ── Period ────────────────────────────────────────────────────────────────────

enum TransactionPeriod { week, month, year }

extension TransactionPeriodX on TransactionPeriod {
  String get label {
    switch (this) {
      case TransactionPeriod.week:
        return 'Semana';
      case TransactionPeriod.month:
        return 'Mes';
      case TransactionPeriod.year:
        return 'Año';
    }
  }

  ({DateTime from, DateTime to}) get dateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case TransactionPeriod.week:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return (from: startOfWeek, to: today);
      case TransactionPeriod.month:
        return (from: DateTime(now.year, now.month, 1), to: today);
      case TransactionPeriod.year:
        return (from: DateTime(now.year, 1, 1), to: today);
    }
  }
}

// ── Selected period ───────────────────────────────────────────────────────────

final selectedPeriodProvider =
    StateProvider<TransactionPeriod>((ref) => TransactionPeriod.month);

// ── Custom date range (overrides period when set) ─────────────────────────────

final customDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final effectiveDateRangeProvider =
    Provider<({DateTime from, DateTime to})>((ref) {
  final custom = ref.watch(customDateRangeProvider);
  if (custom != null) return (from: custom.start, to: custom.end);
  return ref.watch(selectedPeriodProvider).dateRange;
});

// ── Summary ───────────────────────────────────────────────────────────────────

final transactionsSummaryProvider =
    FutureProvider.autoDispose<TransactionsSummary>((ref) {
  final range = ref.watch(effectiveDateRangeProvider);
  final repo = ref.watch(transactionsRepositoryProvider);
  return repo.getSummary(from: range.from, to: range.to);
});

// ── Recent transactions (last 5) ──────────────────────────────────────────────

final recentTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final range = ref.watch(effectiveDateRangeProvider);
  final repo = ref.watch(transactionsRepositoryProvider);
  final all = await repo.getTransactions(from: range.from, to: range.to);
  return all.take(5).toList();
});

// ── All transactions ──────────────────────────────────────────────────────────

final allTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) {
  final range = ref.watch(effectiveDateRangeProvider);
  final repo = ref.watch(transactionsRepositoryProvider);
  return repo.getTransactions(from: range.from, to: range.to);
});

// ── Notifier (CRUD) ───────────────────────────────────────────────────────────

class TransactionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> create(TransactionModel transaction) async {
    await ref.read(transactionsRepositoryProvider).createTransaction(transaction);
    ref.invalidate(transactionsSummaryProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(allTransactionsProvider);
  }

  Future<void> update(TransactionModel transaction) async {
    await ref.read(transactionsRepositoryProvider).updateTransaction(transaction);
    ref.invalidate(transactionsSummaryProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(allTransactionsProvider);
  }

  Future<void> delete(String id) async {
    await ref.read(transactionsRepositoryProvider).deleteTransaction(id);
    ref.invalidate(transactionsSummaryProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(allTransactionsProvider);
  }
}

final transactionsNotifierProvider =
    NotifierProvider<TransactionsNotifier, void>(TransactionsNotifier.new);
