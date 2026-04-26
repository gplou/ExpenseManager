import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/providers/number_format_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/ad_banner_footer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/export_excel_service.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/transactions_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../subscription/subscription_provider.dart';
import 'add_transaction_screen.dart';

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
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
              )
            : null,
        title: _isSelecting
            ? Text(
                l10n.selectedCount(_selectedIds.length),
                style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w600),
              )
            : Text(l10n.history),
        actions: [
          if (_isSelecting)
            transactionsAsync.whenOrNull(
              data: (allTx) => IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.mutedTerra),
                onPressed: _selectedIds.isEmpty ? null : () => _deleteSelected(allTx),
              ),
            ) ?? const SizedBox.shrink()
          else
          transactionsAsync.whenOrNull(
            data: (transactions) {
              final categories = transactions
                  .map((t) => t.category)
                  .toSet()
                  .toList()
                ..sort();
              if (categories.isEmpty) return const SizedBox.shrink();
              final isActive = _selectedCategory != null;
              return PopupMenuButton<String?>(
                icon: Icon(
                  Icons.filter_list_rounded,
                  color: isActive ? AppColors.dustyTeal : null,
                ),
                tooltip: l10n.category,
                onSelected: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = value);
                  if (value != null) {
                    AnalyticsService.track(AnalyticsService.categoryFilterApplied, {'category': value});
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(
                          Icons.clear_all_rounded,
                          size: 18,
                          color: _selectedCategory == null
                              ? AppColors.dustyTeal
                              : AppColors.textMuted,
                        ),
                        const Gap(10),
                        Text(
                          l10n.allCategories,
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontWeight: _selectedCategory == null
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _selectedCategory == null
                                ? AppColors.dustyTeal
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  ...categories.map((cat) => PopupMenuItem<String?>(
                    value: cat,
                    child: Row(
                      children: [
                        Icon(
                          cat == _selectedCategory
                              ? Icons.check_rounded
                              : Icons.label_outline_rounded,
                          size: 18,
                          color: cat == _selectedCategory
                              ? AppColors.dustyTeal
                              : AppColors.textMuted,
                        ),
                        const Gap(10),
                        Text(
                          TransactionCategories.localizedName(cat, l10n),
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontWeight: cat == _selectedCategory
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: cat == _selectedCategory
                                ? AppColors.dustyTeal
                                : null,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: transactionsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.dustyTeal),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const Gap(12),
              Text(
                l10n.errorLoading,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 16,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(16),
              GestureDetector(
                onTap: () => ref.invalidate(allTransactionsProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.dustyTealLight,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    l10n.retry,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.dustyTeal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (allTx) {
          final transactions = _selectedCategory == null
              ? allTx
              : allTx.where((t) => t.category == _selectedCategory).toList();
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.dustyTealLight.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('\uD83D\uDCED', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                  const Gap(20),
                  Text(
                    l10n.noTransactions,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    l10n.noTransactionsPeriod,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            );
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
                          child: _DateHeader(date: entry.date, l10n: l10n),
                        ),
                        ...entry.transactions.map(
                          (t) => _TransactionTile(
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
                _DeleteSelectedButton(
                  count: _selectedIds.length,
                  onTap: _selectedIds.isEmpty ? null : () => _deleteSelected(allTx),
                )
              else
                _ExportButton(
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

  List<_DateGroup> _groupByDate(List<TransactionModel> transactions) {
    final map = <String, _DateGroup>{};
    for (final t in transactions) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      map.putIfAbsent(key, () => _DateGroup(t.date)).transactions.add(t);
    }
    return map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}

// ── Export button ─────────────────────────────────────────────────────────────

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onTap, required this.exporting, required this.label});
  final VoidCallback? onTap;
  final bool exporting;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: BoxDecoration(
              color: onTap != null ? AppColors.dustyTeal : AppColors.dustyTeal.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (exporting)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.pureWhite,
                    ),
                  )
                else
                  const Icon(Icons.download_rounded, color: AppColors.pureWhite, size: 20),
                const Gap(8),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pureWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Delete selected button ────────────────────────────────────────────────────

class _DeleteSelectedButton extends StatelessWidget {
  const _DeleteSelectedButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: BoxDecoration(
              color: onTap != null
                  ? AppColors.mutedTerra
                  : AppColors.mutedTerra.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_outline_rounded, color: AppColors.pureWhite, size: 20),
                const Gap(8),
                Text(
                  '${l10n.delete} ($count)',
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pureWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateGroup {
  _DateGroup(this.date);
  final DateTime date;
  final List<TransactionModel> transactions = [];
}

// ── Date header ───────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.l10n});
  final DateTime date;
  final AppLocalizations l10n;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return l10n.today;
    if (d == today.subtract(const Duration(days: 1))) return l10n.yesterday;
    return DateFormat('EEEE, d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _label(),
          style: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const Gap(10),
        const Expanded(
          child: Divider(color: AppColors.borderLight, thickness: 1),
        ),
      ],
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({
    required this.transaction,
    required this.isSelecting,
    required this.isSelected,
    required this.onLongPress,
    this.onSelectTap,
  });
  final TransactionModel transaction;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback? onSelectTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final isIncome = transaction.type.isIncome;
    final accentColor = isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight = isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;
    final emoji = _emojiForCategory(transaction.category, isIncome);
    final customCats = ref.watch(customCategoriesSyncProvider)[transaction.type] ?? const [];
    TransactionCategory? customCat;
    for (final c in customCats) {
      if (c.name == transaction.category) { customCat = c; break; }
    }

    void handleTap() {
      if (onSelectTap != null) {
        onSelectTap!();
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(transaction: transaction),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(transaction.id),
        direction: isSelecting ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.mutedTerraLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.mutedTerra, size: 26),
        ),
        confirmDismiss: isSelecting ? null : (_) async {
          final isRecurring = transaction.recurringTransactionId != null;
          final String confirmMessage;
          if (isRecurring) {
            confirmMessage = transaction.type.isExpense
                ? l10n.deleteRecurringExpenseConfirm
                : l10n.deleteRecurringIncomeConfirm;
          } else {
            confirmMessage = l10n.deleteTransactionConfirm;
          }
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.delete),
              content: Text(confirmMessage),
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
        },
        onDismissed: isSelecting ? null : (_) async {
          await ref
              .read(transactionsNotifierProvider.notifier)
              .delete(transaction.id, recurringTransactionId: transaction.recurringTransactionId);
        },
        child: GestureDetector(
          onTap: handleTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? accentLight : cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected ? null : AppColors.softShadowSm,
              border: isSelected
                  ? Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Barra lateral de acento
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelecting
                                    ? (isSelected ? accentColor : AppColors.borderLight)
                                    : accentLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: isSelecting
                                    ? Icon(
                                        isSelected
                                            ? Icons.check_rounded
                                            : Icons.circle_outlined,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSubtle,
                                        size: 22,
                                      )
                                    : (customCat != null
                                        ? customCat.emojiOverride != null
                                            ? Text(customCat.emojiOverride!, style: const TextStyle(fontSize: 22))
                                            : Icon(customCat.icon, size: 22, color: accentColor)
                                        : Text(emoji, style: const TextStyle(fontSize: 22))),
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    TransactionCategories.localizedName(
                                      transaction.category,
                                      l10n,
                                    ),
                                    style: TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (transaction.subcategory != null)
                                    Text(
                                      transaction.subcategory!,
                                      style: const TextStyle(
                                        fontFamily: 'Sora',
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  else if (transaction.description != null)
                                    Text(
                                      transaction.description!,
                                      style: const TextStyle(
                                        fontFamily: 'Sora',
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const Gap(8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${isIncome ? '+' : '-'}${currencySymbol(ref.watch(currencyProvider).value ?? 'EUR')}${formatAmount(transaction.amount, ref.watch(numberFormatProvider).value ?? NumberFormatStyle.dotDecimal)}',
                                  style: TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                                Text(
                                  transaction.date.formattedDate,
                                  style: const TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 11,
                                    color: AppColors.textSubtle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _emojiForCategory(String category, bool isIncome) =>
      TransactionCategories.emojiFor(category, isIncome: isIncome);
}
