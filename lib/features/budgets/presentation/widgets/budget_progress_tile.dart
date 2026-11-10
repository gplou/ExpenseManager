import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/motion/motion.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Fila de presupuesto: chip de icono, categoría, cuánto queda y una barra
/// fina coloreada por tramo (<80% acento, 80–100% warning, >100% negative).
///
/// Muestra lo que QUEDA, no lo gastado: es el dato accionable. Al pasarse,
/// cambia a lo excedido, que es la otra cara del mismo dato.
/// Compartido entre el dashboard y BudgetsScreen.
///
/// Movimiento: la barra se rellena desde 0 al aparecer, avanza (y cambia de
/// color) cuando el gasto sube, la cifra de "quedan" cuenta hacia el nuevo
/// valor, y al cruzar un tramo (80% o 100%) la barra y el icono destellan una
/// vez en el color del nuevo tramo — el mismo momento en que salta el aviso.
class BudgetProgressTile extends StatefulWidget {
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
  State<BudgetProgressTile> createState() => _BudgetProgressTileState();
}

class _BudgetProgressTileState extends State<BudgetProgressTile> {
  /// Se incrementa cada vez que el progreso sube de tramo; dispara el destello.
  int _tierCrossings = 0;

  static int _tier(double ratio) => ratio >= 1.0 ? 2 : (ratio >= 0.8 ? 1 : 0);

  @override
  void didUpdateWidget(BudgetProgressTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameBudget =
        oldWidget.progress.budget.id == widget.progress.budget.id;
    if (sameBudget &&
        _tier(widget.progress.ratio) > _tier(oldWidget.progress.ratio)) {
      _tierCrossings++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final progress = widget.progress;
    final cSymbol = widget.cSymbol;
    final numFmtStyle = widget.numFmtStyle;
    final budget = progress.budget;
    final ratio = progress.ratio;

    // Lo que queda; si se pasó, lo excedido. Un "-0 disponible" no dice
    // nada, y el exceso sí es accionable.
    final remaining = budget.amount - progress.spent;
    final isOver = remaining < 0;
    String remainingLabel(double remaining) => remaining < 0
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
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            HighlightPulse(
              trigger: _tierCrossings,
              color: barColor,
              scale: 1.08,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
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
                      AnimatedAmount(
                        value: remaining,
                        duration: MotionTokens.fill,
                        formatter: remainingLabel,
                        style: context.textTheme.bodySmall!.copyWith(
                          color: isOver
                              ? AppColors.negative
                              : context.appColors.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const Gap(6),
                  HighlightPulse(
                    trigger: _tierCrossings,
                    color: barColor,
                    scale: 1.0,
                    // Tras el relleno de la barra, para que el destello
                    // llegue cuando la barra ya ha alcanzado el nuevo tramo.
                    delayIndex: 4,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: AnimatedProgressBar(
                      value: ratio,
                      color: barColor,
                      backgroundColor: context.appColors.raised,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const Gap(4),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
