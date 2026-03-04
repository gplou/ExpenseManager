import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/custom_date_range_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/export_excel_service.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/transactions_provider.dart';
import 'add_transaction_screen.dart';

class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends ConsumerState<TransactionsListScreen> {
  bool _exporting = false;

  Future<void> _exportToExcel(List<TransactionModel> transactions) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      await ExportExcelService.exportTransactions(transactions, l10n);
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
    final period = ref.watch(selectedPeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final cs = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.history),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...TransactionPeriod.values.map((p) {
                    final isSelected = p == period && customRange == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _PeriodChip(
                        label: p.l10nLabel(l10n),
                        isSelected: isSelected,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(selectedPeriodProvider.notifier).state = p;
                          ref.read(customDateRangeProvider.notifier).state = null;
                        },
                      ),
                    );
                  }),
                  _IconChip(
                    icon: Icons.calendar_month_outlined,
                    isActive: customRange != null,
                    onTap: () async {
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
                        ref.read(customDateRangeProvider.notifier).state = range;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: transactionsAsync.when(
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
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📭', style: TextStyle(fontSize: 64)),
                  const Gap(16),
                  Text(
                    l10n.noTransactions,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                          (t) => _TransactionTile(transaction: t),
                        ),
                      ],
                    );
                  },
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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

// ── Period chip ───────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.dustyTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.dustyTeal : AppColors.borderMedium,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.pureWhite : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.warmAmberLight : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? AppColors.warmAmber : AppColors.borderMedium,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? AppColors.warmAmber : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final isIncome = transaction.type.isIncome;
    final accentColor = isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight = isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;
    final emoji = _emojiForCategory(transaction.category, isIncome);
    final customCats = ref.watch(customCategoriesProvider)[transaction.type] ?? const [];
    IconData? customIcon;
    for (final c in customCats) {
      if (c.name == transaction.category) { customIcon = c.icon; break; }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(transaction.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.mutedTerraLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.mutedTerra, size: 26),
        ),
        confirmDismiss: (_) async {
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
        onDismissed: (_) async {
          await ref
              .read(transactionsNotifierProvider.notifier)
              .delete(transaction.id, recurringTransactionId: transaction.recurringTransactionId);
        },
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(transaction: transaction),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadowSm,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: customIcon != null
                          ? Icon(customIcon, size: 22, color: accentColor)
                          : Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (transaction.description != null)
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
                    children: [
                      Text(
                        '${isIncome ? '+' : '-'}€${transaction.amount.toStringAsFixed(2)}',
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
        ),
      ),
    );
  }

  String _emojiForCategory(String category, bool isIncome) => switch (category) {
    'Salario'    => '💼',
    'Freelance'  => '💻',
    'Inversión'  => '📈',
    'Regalo'     => '🎁',
    'Comida'     => '🍕',
    'Transporte' => '🚗',
    'Vivienda'   => '🏠',
    'Ocio'       => '🎮',
    'Salud'      => '💊',
    'Educación'  => '📚',
    'Ropa'       => '👕',
    'Tecnología' => '⚡',
    _            => isIncome ? '💰' : '💸',
  };
}
