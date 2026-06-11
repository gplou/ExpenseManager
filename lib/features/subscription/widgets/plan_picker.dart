import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/neo_card.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

class PlanPicker extends StatelessWidget {
  const PlanPicker({super.key, 
    required this.packages,
    required this.selected,
    required this.onChanged,
  });

  final List<Package> packages;
  final Package selected;
  final ValueChanged<Package> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: packages.map((pkg) {
        final isSelected = pkg.identifier == selected.identifier;
        final isAnnual = pkg.packageType == PackageType.annual;
        final price = pkg.storeProduct.priceString;
        final savingsLabel = _annualSavings(packages, pkg);

        return GestureDetector(
          onTap: () => onChanged(pkg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.dustyTeal.withValues(alpha: 0.08)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected ? AppColors.dustyTeal : AppColors.textMuted.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected ? AppColors.dustyTeal : AppColors.textMuted,
                  size: 20,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _periodLabel(context, pkg),
                            style: TextStyle(
                              fontFamily: 'GeneralSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.dustyTeal
                                  : null,
                            ),
                          ),
                          if (isAnnual && savingsLabel != null) ...[
                            const Gap(8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.sageGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                savingsLabel,
                                style: const TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _perMonthLabel(context, pkg),
                        style: const TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.dustyTeal : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _periodLabel(BuildContext context, Package pkg) {
    final l10n = AppLocalizations.of(context);
    return switch (pkg.packageType) {
      PackageType.annual => l10n.planAnnual,
      PackageType.monthly => l10n.planMonthly,
      PackageType.weekly => l10n.planWeekly,
      _ => pkg.storeProduct.title,
    };
  }

  String _perMonthLabel(BuildContext context, Package pkg) {
    final l10n = AppLocalizations.of(context);
    if (pkg.packageType == PackageType.annual) {
      final perMonth = pkg.storeProduct.price / 12;
      final symbol = _currencySymbol(pkg.storeProduct.currencyCode);
      return l10n.planPerMonth('$symbol${perMonth.toStringAsFixed(2)}');
    }
    return l10n.proPriceSubtitle;
  }

  String _currencySymbol(String code) => switch (code.toUpperCase()) {
        'EUR' => '€',
        'USD' => '\$',
        'GBP' => '£',
        _ => '$code ',
      };

  /// Returns a "Save X%" label when the annual plan is cheaper per month
  /// than the monthly plan.
  String? _annualSavings(List<Package> all, Package annualPkg) {
    final monthly = all.firstWhere(
      (p) => p.packageType == PackageType.monthly,
      orElse: () => annualPkg,
    );
    if (monthly.identifier == annualPkg.identifier) return null;
    final monthlyPrice = monthly.storeProduct.price;
    if (monthlyPrice <= 0) return null;
    final annualPerMonth = annualPkg.storeProduct.price / 12;
    final savings = ((1 - annualPerMonth / monthlyPrice) * 100).round();
    if (savings <= 0) return null;
    return '-$savings%';
  }
}

class PlanPickerFallback extends StatelessWidget {
  const PlanPickerFallback({super.key, required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      accentColor: AppColors.warmAmber,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            l10n.planMonthly,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.dustyTeal,
            ),
          ),
          const Gap(4),
          Text(
            l10n.proPriceSubtitle,
            style: const TextStyle(
              fontFamily: 'GeneralSans',
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class PlanPickerSkeleton extends StatelessWidget {
  const PlanPickerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(2, (i) {
        return Container(
          height: 62,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
        );
      }),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
