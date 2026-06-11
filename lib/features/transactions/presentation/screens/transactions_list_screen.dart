import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/ad_banner_footer.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/data/export_excel_service.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/transaction_list_tile.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/transactions_filter_button.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/transactions_list_footer.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/transactions_list_states.dart';

class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends ConsumerState<TransactionsListScreen> {
  bool _exporting = false;
  String? _selectedCategory; // null = todas
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelecting = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected(List<TransactionModel> allTransactions) async {
    final l10n = AppLocalizations.of(context);
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteSelectedConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.mutedTerra),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final notifier = ref.read(transactionsNotifierProvider.notifier);
    final toDelete = allTransactions.where((t) => _selectedIds.contains(t.id)).toList();
    for (final t in toDelete) {
      await notifier.delete(t.id, recurringTransactionId: t.recurringTransactionId);
    }
    _exitSelectionMode();
  }

  Future<void> _exportToExcel(List<TransactionModel> transactions) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      await ExportExcelService.exportTransactions(transactions, l10n);
      AnalyticsService.track(AnalyticsService.exportExcel, {'count': transactions.length});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.exportError),
            backgroundColor: AppColors.mutedTerra,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final cs = context.colors;

    return Scaffold(
      bottomNavigationBar: ref.watch(isProProvider) ? null : const AdBannerFooter(),
      appBar: AppBar(
        leading: _isSelecting
            ? IconButton(
                tooltip: l10n.cancel,
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
              )
            : null,
        title: _isSelecting
            ? Text(
                l10n.selectedCount(_selectedIds.length),
                style: const TextStyle(fontFamily: 'GeneralSans', fontWeight: FontWeight.w600),
              )
            : Text(l10n.history),
        actions: [
          if (_isSelecting)
            transactionsAsync.whenOrNull(
              data: (allTx) => IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.mutedTerra),
                onPressed: _selectedIds.isEmpty ? null : () => _deleteSelected(allTx),
              ),
            ) ?? const SizedBox.shrink()
          else
            transactionsAsync.whenOrNull(
              data: (_) => CategoryFilterButton(
                l10n: l10n,
                selectedCategory: _selectedCategory,
                onSelected: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = value);
                  if (value != null) {
                    AnalyticsService.track(
                        AnalyticsService.categoryFilterApplied,
                        {'category': value});
                  }
                },
              ),
            ) ??
                const SizedBox.shrink(),
        ],
      ),
      body: transactionsAsync.when(
        skipLoadingOnReload: true,
        loading: () => Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
        error: (e, _) => ErrorState(
          l10n: l10n,
          onRetry: () => ref.invalidate(allTransactionsProvider),
        ),
        data: (allTx) {
          final transactions = _selectedCategory == null
              ? allTx
              : allTx.where((t) => t.category == _selectedCategory).toList();
          if (transactions.isEmpty) {
            return EmptyState(l10n: l10n);
          }

          final grouped = _groupByDate(transactions);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final entry = grouped[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
                          child: DateHeader(date: entry.date, l10n: l10n),
                        ),
                        ...entry.transactions.map(
                          (t) => TransactionTile(
                            transaction: t,
                            isSelecting: _isSelecting,
                            isSelected: _selectedIds.contains(t.id),
                            onLongPress: () => _isSelecting
                                ? _toggleSelection(t.id)
                                : _enterSelectionMode(t.id),
                            onSelectTap: _isSelecting
                                ? () => _toggleSelection(t.id)
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_isSelecting)
                DeleteSelectedButton(
                  count: _selectedIds.length,
                  onTap: _selectedIds.isEmpty ? null : () => _deleteSelected(allTx),
                )
              else
                ExportButton(
                  onTap: _exporting ? null : () => _exportToExcel(transactions),
                  exporting: _exporting,
                  label: l10n.exportExcel,
                ),
            ],
          );
        },
      ),
    );
  }

  List<DateGroup> _groupByDate(List<TransactionModel> transactions) {
    final map = <String, DateGroup>{};
    for (final t in transactions) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      map.putIfAbsent(key, () => DateGroup(t.date)).transactions.add(t);
    }
    return map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}

// ── Category filter button (AppBar action) ────────────────────────────────────
