import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Fila de presupuesto: chip de icono, categoría, cuánto queda y una barra
/// fina coloreada por tramo (<80% acento, 80–100% warning, >100% negative).
///
/// Muestra lo que QUEDA, no lo gastado: es el dato accionable. Al pasarse,
/// cambia a lo excedido, que es la otra cara del mismo dato.
/// Compartido entre el dashboard y BudgetsScreen.
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

    // Lo que queda; si se pasó, lo excedido. Un "-0 disponible" no dice
    // nada, y el exceso sí es accionable.
    final remaining = budget.amount - progress.spent;
    final isOver = remaining < 0;
    final remainingLabel = isOver
        ? '+$cSymbol${formatAmount(remaining.abs(), numFmtStyle)}'
        : l10n.amountLeft(
            '$cSymbol${formatAmount(remaining, numFmtStyle)}',
          );

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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.appColors.raised,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                TransactionCategories.phosphorFor(budget.category),
                size: 20,
                color: cs.onSurface,
              ),
            ),
            const Gap(12),
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
                        remainingLabel,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: isOver
                              ? AppColors.negative
                              : context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Gap(6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 4,
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
