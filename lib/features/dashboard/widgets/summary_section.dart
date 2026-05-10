import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/providers/number_format_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../transactions/domain/transactions_repository_contract.dart';
import '../../tutorial/tutorial_keys.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = summary.balance;
    final isPositive = balance >= 0;
    final accentColor = isPositive ? AppColors.sageGreen : AppColors.mutedTerra;
    final total = summary.income + summary.expense;
    final incomePercent = total > 0 ? (summary.income / total * 100).round() : 0;
    final expensePercent = total > 0 ? (summary.expense / total * 100).round() : 0;

    return Column(
      children: [
        Container(
          key: TutorialKeys.balanceCardKey,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorderColor : AppColors.borderLight,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: accentColor,
                    ),
                    const Gap(4),
                    Text(
                      l10n.balance.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(10),
              AnimatedAmount(
                value: balance,
                formatter: (v) => '${v < 0 ? '-' : ''}$cSymbol${formatAmount(v.abs(), numFmtStyle)}',
                style: context.textTheme.headlineLarge!.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (total > 0) ...[
                const Gap(12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: SizedBox(
                    height: 5,
                    child: Row(
                      children: [
                        Expanded(
                          flex: incomePercent.clamp(1, 99),
                          child: Container(color: AppColors.sageGreen),
                        ),
                        const Gap(2),
                        Expanded(
                          flex: expensePercent.clamp(1, 99),
                          child: Container(color: AppColors.mutedTerra),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const Gap(12),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? AppColors.darkBorderColor.withValues(alpha: 0.5)
                    : AppColors.borderLight.withValues(alpha: 0.7),
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.sageGreen.withValues(alpha: isDark ? 0.15 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.south_west_rounded,
                            size: 16,
                            color: AppColors.sageGreen,
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.income,
                                style: TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              AnimatedAmount(
                                value: summary.income,
                                formatter: (v) =>
                                    '$cSymbol${formatAmount(v, numFmtStyle)}',
                                style: const TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sageGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: isDark
                        ? AppColors.darkBorderColor.withValues(alpha: 0.5)
                        : AppColors.borderLight.withValues(alpha: 0.7),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.mutedTerra.withValues(alpha: isDark ? 0.15 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.north_east_rounded,
                            size: 16,
                            color: AppColors.mutedTerra,
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.expenses,
                                style: TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              AnimatedAmount(
                                value: summary.expense,
                                formatter: (v) =>
                                    '$cSymbol${formatAmount(v, numFmtStyle)}',
                                style: const TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mutedTerra,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: TutorialKeys.chartsBtnKey,
            onPressed: onViewCharts,
            icon: const Icon(Icons.pie_chart_outline, size: 18),
            label: Text(l10n.viewCharts),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dustyTeal,
              side: const BorderSide(color: AppColors.dustyTeal, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
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
    final baseColor = isDark ? AppColors.darkSurfaceHigh : const Color(0xFFECEAE4);
    final highlightColor = isDark ? AppColors.darkSurface.withValues(alpha: 0.7) : const Color(0xFFF8F7F2);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 185,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const Gap(12),
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}
