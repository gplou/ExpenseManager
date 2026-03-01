import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/custom_date_range_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/transactions_provider.dart';
import 'add_transaction_screen.dart';

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(selectedPeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.history),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...TransactionPeriod.values.map((p) {
                  final isSelected = p == period && customRange == null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(p.l10nLabel(l10n)),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(selectedPeriodProvider.notifier).state = p;
                        ref.read(customDateRangeProvider.notifier).state =
                            null;
                      },
                    ),
                  );
                }),
                IconButton(
                  icon: Icon(
                    Icons.calendar_month_outlined,
                    color: customRange != null
                        ? context.colors.primary
                        : null,
                  ),
                  tooltip: l10n.customRange,
                  onPressed: () async {
                    final range = await showCustomDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: customRange ??
                          DateTimeRange(
                            start: period.dateRange.from,
                            end: period.dateRange.to,
                          ),
                    );
                    if (range != null) {
                      ref.read(customDateRangeProvider.notifier).state =
                          range;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: transactionsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.errorLoading,
                  style: context.textTheme.bodyLarge),
              const Gap(8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(allTransactionsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: context.colors.onSurface.withValues(alpha: 0.3),
                  ),
                  const Gap(16),
                  Text(
                    l10n.noTransactions,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.colors.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          final grouped = _groupByDate(transactions);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final entry = grouped[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      _formatGroupDate(entry.date, l10n),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colors.onSurface
                            .withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...entry.transactions.map(
                    (t) => _TransactionTile(transaction: t),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<TransactionModel> transactions) {
    final map = <String, _DateGroup>{};
    for (final t in transactions) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      map.putIfAbsent(key, () => _DateGroup(t.date)).transactions.add(t);
    }
    return map.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  String _formatGroupDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return l10n.today;
    if (d == today.subtract(const Duration(days: 1))) return l10n.yesterday;
    // Uses Intl.defaultLocale set by the locale provider
    return DateFormat('EEEE, d MMMM').format(date).toUpperCase();
  }
}

class _DateGroup {
  _DateGroup(this.date);
  final DateTime date;
  final List<TransactionModel> transactions = [];
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isIncome = transaction.type.isIncome;
    final color = isIncome ? Colors.green : Colors.red;
    final customCats = ref.watch(customCategoriesProvider);
    final icon = TransactionCategories.iconFor(
      transaction.category,
      transaction.type,
      extra: customCats[transaction.type] ?? [],
    );

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.delete),
            content: Text(l10n.deleteTransactionConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l10n.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await ref
            .read(transactionsNotifierProvider.notifier)
            .delete(transaction.id);
      },
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                AddTransactionScreen(transaction: transaction),
          ),
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          TransactionCategories.localizedName(transaction.category, l10n),
          style: context.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: transaction.description != null
            ? Text(
                transaction.description!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Text(
          '${isIncome ? '+' : '-'}€${transaction.amount.toStringAsFixed(2)}',
          style: context.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
