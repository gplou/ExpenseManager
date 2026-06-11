import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'chart_area.dart';

class ChartStatCard extends StatelessWidget {
  const ChartStatCard({super.key, 
    required this.eyebrow,
    required this.amountAsync,
    required this.cSymbol,
    required this.numFmt,
    required this.accentColor,
    required this.isIncome,
    required this.l10n,
    required this.mode,
    required this.onModeChanged,
  });

  final String eyebrow;
  final AsyncValue<double> amountAsync;
  final String cSymbol;
  final NumberFormatStyle numFmt;
  final Color accentColor;
  final bool isIncome;
  final AppLocalizations l10n;
  final ChartMode mode;
  final ValueChanged<ChartMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.appColors.divider, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textMuted,
                    letterSpacing: 1.2,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(AppSpacing.sm),
                amountAsync.when(
                  loading: () => Text(
                    '...',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.text,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  error: (_, __) => Text(
                    l10n.errorLoading,
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 13,
                      color: accentColor,
                    ),
                  ),
                  data: (total) => Text(
                    '$cSymbol${formatAmount(total, numFmt)}',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.text,
                      letterSpacing: -0.6,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncome
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 13,
                      color: accentColor,
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      isIncome ? l10n.typeIncome : l10n.typeExpense,
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          ChartModeSwitch(
            mode: mode,
            onChanged: onModeChanged,
          ),
        ],
      ),
    );
  }
}

// ── Chart mode switch (pie/bar, vertical compact) ─────────────────────────────

class ChartModeSwitch extends StatelessWidget {
  const ChartModeSwitch({super.key, required this.mode, required this.onChanged});

  final ChartMode mode;
  final ValueChanged<ChartMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appColors.raised,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChartModeIcon(
            icon: Icons.pie_chart_rounded,
            isSelected: mode == ChartMode.pie,
            onTap: () => onChanged(ChartMode.pie),
          ),
          const Gap(2),
          ChartModeIcon(
            icon: Icons.bar_chart_rounded,
            isSelected: mode == ChartMode.bar,
            onTap: () => onChanged(ChartMode.bar),
          ),
        ],
      ),
    );
  }
}

class ChartModeIcon extends StatelessWidget {
  const ChartModeIcon({super.key, 
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? context.appColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md - 3),
          boxShadow: isSelected && !isDark ? AppColors.softShadowSm : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? context.appColors.text : context.appColors.textMuted,
        ),
      ),
    );
  }
}

// ── Type toggle (Income / Expense) — full width ───────────────────────────────
