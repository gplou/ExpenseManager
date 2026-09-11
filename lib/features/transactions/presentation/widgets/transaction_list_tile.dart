import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/features/transactions/presentation/screens/add_transaction_screen.dart';

class DateGroup {
  DateGroup(this.date);
  final DateTime date;
  final List<TransactionModel> transactions = [];
}

// ── Date header ───────────────────────────────────────────────────────────────

class DateHeader extends StatelessWidget {
  const DateHeader({super.key, required this.date, required this.l10n});
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
          child: Container(height: 1, color: context.appColors.divider),
        ),
      ],
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class TransactionTile extends ConsumerWidget {
  const TransactionTile({super.key, 
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
    final isIncome = transaction.type.isIncome;
    final amountColor = isIncome ? AppColors.positive : AppColors.negative;
    final avatarBg = context.appColors.raised;
    final secondaryText = context.appColors.textMuted;
    final dividerColor = context.appColors.divider;
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
          ? cs.primary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.06)
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
                          ? PhosphorIcons.check()
                          : PhosphorIcons.circle(),
                      color: isSelected
                          ? cs.onPrimary
                          : cs.onSurface.withValues(alpha: 0.5),
                      size: 20,
                    )
                  : (customCat != null
                      ? customCat.emojiOverride != null
                          ? Text(customCat.emojiOverride!,
                              style:
                                  const TextStyle(fontSize: AppEmojiSize.medium))
                          : Icon(customCat.icon,
                              size: 18, color: cs.onSurface)
                      : Text(emoji,
                          style:
                              const TextStyle(fontSize: AppEmojiSize.medium))),
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
          child: Icon(PhosphorIcons.trash(),
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
