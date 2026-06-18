import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Barra de progreso de un presupuesto: emoji + categoría localizada,
/// "gastado / límite" y barra coloreada por tramo (<80% primario, 80–100%
/// warning, >100% negative). Compartido entre el dashboard y BudgetsScreen.
class BudgetProgressTile extends StatelessWidget {
  const BudgetProgressTile({
    super.key,
    required this.progress,
    required this.cSymbol,
    required this.numFmtStyle,
    this.onTap,
    this.trailing,
  });

  final BudgetProgress progress;
  final String cSymbol;
  final NumberFormatStyle numFmtStyle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final budget = progress.budget;
    final ratio = progress.ratio;

    final barColor = ratio >= 1.0
        ? AppColors.negative
        : ratio >= 0.8
            ? AppColors.warning
            : cs.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Text(
              TransactionCategories.emojiFor(budget.category),
              style: const TextStyle(fontSize: 18),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          TransactionCategories.localizedName(
                              budget.category, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Gap(8),
                      Text(
                        '$cSymbol${formatAmount(progress.spent, numFmtStyle)}'
                        ' / '
                        '$cSymbol${formatAmount(budget.amount, numFmtStyle)}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const Gap(6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: context.appColors.raised,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const Gap(4), trailing!],
          ],
        ),
      ),
    );
  }
}
