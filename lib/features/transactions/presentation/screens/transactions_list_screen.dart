import 'package:clock/clock.dart';
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
            data: (_) {
              // Distinct, sorted categories come pre-computed from a memoized
              // provider — no per-rebuild distinct+sort here.
              final categories =
                  ref.watch(transactionCategoryOptionsProvider).value ??
                      const <String>[];
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
                            fontFamily: 'GeneralSans',
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
                            fontFamily: 'GeneralSans',
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
        loading: () => Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.negativeSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.negative,
                    size: 24,
                  ),
                ),
                const Gap(16),
                Text(
                  l10n.errorLoading,
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const Gap(14),
                InkWell(
                  onTap: () => ref.invalidate(allTransactionsProvider),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.retry,
                          style: context.textTheme.labelLarge?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(4),
                        Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (allTx) {
          final transactions = _selectedCategory == null
              ? allTx
              : allTx.where((t) => t.category == _selectedCategory).toList();
          if (transactions.isEmpty) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.raisedDark : AppColors.raised,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inbox_outlined,
                        size: 26,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const Gap(16),
                    Text(
                      l10n.noTransactions,
                      textAlign: TextAlign.center,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      l10n.noTransactionsPeriod,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
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
  const _ExportButton(
      {required this.onTap, required this.exporting, required this.label});
  final VoidCallback? onTap;
  final bool exporting;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        isDark ? AppColors.dividerDark : AppColors.divider;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: dividerColor, width: 1)),
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.paper,
                  ),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(label),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        isDark ? AppColors.dividerDark : AppColors.divider;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: dividerColor, width: 1)),
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.negative,
            foregroundColor: AppColors.paper,
            disabledBackgroundColor:
                AppColors.negative.withValues(alpha: 0.4),
            disabledForegroundColor: AppColors.paper,
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: Text('${l10n.delete} ($count)'),
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
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return l10n.today;
    if (d == today.subtract(const Duration(days: 1))) return l10n.yesterday;
    return DateFormat('EEEE, d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        isDark ? AppColors.dividerDark : AppColors.divider;
    return Row(
      children: [
        Text(
          _label().toUpperCase(),
          style: context.textTheme.labelMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Container(height: 1, color: dividerColor),
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
    final tt = context.textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.type.isIncome;
    final amountColor = isIncome ? AppColors.positive : AppColors.negative;
    final avatarBg = isDark ? AppColors.raisedDark : AppColors.raised;
    final secondaryText =
        isDark ? AppColors.graphiteDark : AppColors.graphite;
    final dividerColor =
        isDark ? AppColors.dividerDark : AppColors.divider;
    final emoji = _emojiForCategory(transaction.category, isIncome);
    final customCats =
        ref.watch(customCategoriesSyncProvider)[transaction.type] ?? const [];
    TransactionCategory? customCat;
    for (final c in customCats) {
      if (c.name == transaction.category) {
        customCat = c;
        break;
      }
    }

    void handleTap() {
      if (onSelectTap != null) {
        onSelectTap!();
      } else {
        showAddTransactionSheet(context, transaction: transaction);
      }
    }

    final amountStr =
        '${isIncome ? '+' : '-'}${currencySymbol(ref.watch(currencyProvider).value ?? 'EUR')}${formatAmount(transaction.amount, ref.watch(numberFormatProvider).value ?? NumberFormatStyle.dotDecimal)}';

    final rowContent = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      color: isSelected
          ? cs.primary.withValues(alpha: isDark ? 0.18 : 0.06)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          // ── Avatar / checkbox ─────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelecting && isSelected
                  ? cs.primary
                  : avatarBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isSelecting
                  ? Icon(
                      isSelected
                          ? Icons.check_rounded
                          : Icons.circle_outlined,
                      color: isSelected
                          ? cs.onPrimary
                          : cs.onSurface.withValues(alpha: 0.5),
                      size: 20,
                    )
                  : (customCat != null
                      ? customCat.emojiOverride != null
                          ? Text(customCat.emojiOverride!,
                              style: const TextStyle(fontSize: 18))
                          : Icon(customCat.icon,
                              size: 18, color: cs.onSurface)
                      : Text(emoji, style: const TextStyle(fontSize: 18))),
            ),
          ),
          const Gap(14),
          // ── Texto ─────────────────────────────────────────────────
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
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: -0.1,
                  ),
                ),
                if (transaction.subcategory != null) ...[
                  const Gap(2),
                  Text(
                    transaction.subcategory!,
                    style: tt.bodySmall?.copyWith(color: secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (transaction.description != null) ...[
                  const Gap(2),
                  Text(
                    transaction.description!,
                    style: tt.bodySmall?.copyWith(color: secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Gap(12),
          // ── Importe + fecha ───────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                amountStr,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                  letterSpacing: -0.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Gap(2),
              Text(
                transaction.date.formattedDate,
                style: tt.bodySmall?.copyWith(
                  color: secondaryText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
      ),
      child: Dismissible(
        key: ValueKey(transaction.id),
        direction:
            isSelecting ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: AppColors.negativeSoft,
          child: const Icon(Icons.delete_outline_rounded,
              color: AppColors.negative, size: 22),
        ),
        confirmDismiss: isSelecting
            ? null
            : (_) async {
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
                          style:
                              const TextStyle(color: AppColors.negative),
                        ),
                      ),
                    ],
                  ),
                );
              },
        onDismissed: isSelecting
            ? null
            : (_) async {
                await ref
                    .read(transactionsNotifierProvider.notifier)
                    .delete(transaction.id,
                        recurringTransactionId:
                            transaction.recurringTransactionId);
              },
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            handleTap();
          },
          onLongPress: onLongPress,
          child: rowContent,
        ),
      ),
    );
  }

  String _emojiForCategory(String category, bool isIncome) =>
      TransactionCategories.emojiFor(category, isIncome: isIncome);
}
