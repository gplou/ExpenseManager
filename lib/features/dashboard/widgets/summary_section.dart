import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/fading_divider.dart';
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

/// Héroe del dashboard: cuánto se ha gastado en el periodo, en grande, y
/// debajo tres cifras de apoyo (ingresos, media diaria, balance).
///
/// El gasto manda sobre el balance a propósito: es el número sobre el que se
/// actúa. El balance sigue ahí, pero como dato de apoyo.
class SummarySection extends StatelessWidget {
  const SummarySection({
    super.key,
    required this.summary,
    required this.cSymbol,
    required this.numFmtStyle,
    required this.periodLabel,
    required this.daysElapsed,
    required this.onViewCharts,
  });
  final TransactionsSummary summary;
  final String cSymbol;
  final NumberFormatStyle numFmtStyle;

  /// Nombre del periodo tal y como se muestra en el eyebrow ("septiembre",
  /// "esta semana"…). Lo resuelve el dashboard, que es quien conoce el filtro.
  final String periodLabel;

  /// Días transcurridos del periodo, para la media diaria. Siempre >= 1: el
  /// primer día del mes el gasto medio es el gasto, no una división por cero.
  final int daysElapsed;

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
    final appColors = context.appColors;
    final dividerColor = appColors.divider;
    final avgPerDay = summary.expense / (daysElapsed < 1 ? 1 : daysElapsed);

    return Container(
      key: TutorialKeys.balanceCardKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Eyebrow: GASTADO EN <PERIODO> ─────────────────────────────
          Text(
            l10n.spentInPeriod(periodLabel).toUpperCase(),
            style: tt.labelMedium?.copyWith(color: appColors.textMuted),
          ),
          const Gap(8),

          // ── Cifra héroe ───────────────────────────────────────────────
          AnimatedAmount(
            value: summary.expense,
            formatter: (v) => '$cSymbol${formatAmount(v, numFmtStyle)}',
            style: tt.displayLarge!.copyWith(
              color: cs.onSurface,
              fontFeatures: _tabularFigures,
            ),
          ),
          const Gap(18),

          FadingDivider(color: dividerColor),
          const Gap(16),

          // ── Tres cifras de apoyo ──────────────────────────────────────
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
              Expanded(
                child: _SummaryCell(
                  label: l10n.avgPerDay,
                  amount: avgPerDay,
                  cSymbol: cSymbol,
                  numFmtStyle: numFmtStyle,
                  amountColor: cs.onSurface,
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: l10n.balance,
                  amount: summary.balance,
                  cSymbol: cSymbol,
                  numFmtStyle: numFmtStyle,
                  amountColor: cs.onSurface,
                ),
              ),
            ],
          ),

          const Gap(14),

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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(4),
                    Icon(
                      PhosphorIcons.arrowRight,
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
    this.prefix = '',
  });

  final String label;
  final double amount;
  final String cSymbol;
  final NumberFormatStyle numFmtStyle;
  final Color amountColor;
  /// Signo opcional delante de la cifra ("+" en ingresos). Vacío deja que
  /// el número muestre su propio signo.
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
          style: tt.titleSmall!.copyWith(
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
