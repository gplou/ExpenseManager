import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/tutorial/tutorial_keys.dart';

/// Texto numérico que interpola entre el valor anterior y el nuevo cuando
/// cambia. Útil para balance / income / expense después de guardar una
/// transacción — el cambio se siente "vivo" en lugar de saltar.
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
  });

  final double value;
  final String Function(double v) formatter;
  final TextStyle style;
  final Duration duration;
  final Curve curve;

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount> {
  late double _previous = widget.value;

  @override
  void didUpdateWidget(AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previous = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations || _previous == widget.value) {
      return Text(widget.formatter(widget.value), style: widget.style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _previous, end: widget.value),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, v, _) => Text(widget.formatter(v), style: widget.style),
    );
  }
}

/// Hero summary editorial Quiet Wealth: eyebrow + número gigante + bento
/// 2-col plano con income/gastos. Sin barra de proporción, sin botón CTA.
class SummarySection extends StatelessWidget {
  const SummarySection({
    super.key,
    required this.summary,
    required this.cSymbol,
    required this.numFmtStyle,
    required this.onViewCharts,
  });
  final TransactionsSummary summary;
  final String cSymbol;
  final NumberFormatStyle numFmtStyle;
  final VoidCallback onViewCharts;

  // Números tabulares (mismas anchuras de dígito) para que la columna no baile.
  static const _tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final tt = context.textTheme;
    final balance = summary.balance;
    final isPositive = balance >= 0;

    final dividerColor = context.appColors.divider;

    return Container(
      key: TutorialKeys.balanceCardKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Eyebrow: BALANCE ──────────────────────────────────────────
          Text(
            l10n.balance.toUpperCase(),
            style: tt.labelMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const Gap(10),

          // ── Número hero ───────────────────────────────────────────────
          AnimatedAmount(
            value: balance,
            formatter: (v) =>
                '${v < 0 ? '-' : ''}$cSymbol${formatAmount(v.abs(), numFmtStyle)}',
            style: tt.displaySmall!.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.2,
              fontFeatures: _tabularFigures,
            ),
          ),
          const Gap(6),

          // ── Indicador inline ──────────────────────────────────────────
          Row(
            children: [
              Icon(
                isPositive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 14,
                color: isPositive
                    ? AppColors.positive
                    : AppColors.negative,
              ),
              const Gap(4),
              Text(
                isPositive ? l10n.income : l10n.expenses,
                style: tt.bodySmall?.copyWith(
                  color: isPositive
                      ? AppColors.positive
                      : AppColors.negative,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Gap(20),

          // ── Hairline divider ──────────────────────────────────────────
          Container(height: 1, color: dividerColor),
          const Gap(18),

          // ── Bento 2-col: income / expense ─────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryCell(
                  label: l10n.income,
                  amount: summary.income,
                  cSymbol: cSymbol,
                  numFmtStyle: numFmtStyle,
                  amountColor: AppColors.positive,
                  prefix: '+',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: dividerColor,
              ),
              Expanded(
                child: _SummaryCell(
                  label: l10n.expenses,
                  amount: summary.expense,
                  cSymbol: cSymbol,
                  numFmtStyle: numFmtStyle,
                  amountColor: AppColors.negative,
                  prefix: '-',
                ),
              ),
            ],
          ),

          const Gap(18),

          // ── Link a charts (discreto, no botón outlined) ───────────────
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              key: TutorialKeys.chartsBtnKey,
              onTap: onViewCharts,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.viewCharts,
                      style: tt.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.amount,
    required this.cSymbol,
    required this.numFmtStyle,
    required this.amountColor,
    required this.prefix,
  });

  final String label;
  final double amount;
  final String cSymbol;
  final NumberFormatStyle numFmtStyle;
  final Color amountColor;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final tt = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: tt.labelMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(6),
        AnimatedAmount(
          value: amount,
          formatter: (v) =>
              '$prefix$cSymbol${formatAmount(v, numFmtStyle)}',
          style: tt.titleLarge!.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class SummaryShimmer extends StatelessWidget {
  const SummaryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.raisedDark : const Color(0xFFECEAE4);
    final highlightColor = isDark
        ? AppColors.surfaceDarkMode.withValues(alpha: 0.7)
        : const Color(0xFFF8F7F2);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
    );
  }
}
