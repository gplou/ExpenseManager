import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

class CategoryFilterButton extends ConsumerWidget {
  const CategoryFilterButton({super.key, 
    required this.l10n,
    required this.selectedCategory,
    required this.onSelected,
  });

  final AppLocalizations l10n;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Distinct, sorted categories come pre-computed from a memoized provider —
    // no per-rebuild distinct+sort here.
    final categories =
        ref.watch(transactionCategoryOptionsProvider).value ??
            const <String>[];
    if (categories.isEmpty) return const SizedBox.shrink();
    final isActive = selectedCategory != null;
    return PopupMenuButton<String?>(
      icon: Icon(
        PhosphorIcons.funnel(),
        color: isActive ? AppColors.dustyTeal : null,
      ),
      tooltip: l10n.category,
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              Icon(
                PhosphorIcons.x(),
                size: 18,
                color: selectedCategory == null
                    ? AppColors.dustyTeal
                    : AppColors.textMuted,
              ),
              const Gap(10),
              Text(
                l10n.allCategories,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: selectedCategory == null
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: selectedCategory == null ? AppColors.dustyTeal : null,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...categories.map((cat) => PopupMenuItem<String?>(
              value: cat,
              child: Row(
                children: [
                  Icon(
                    cat == selectedCategory
                        ? PhosphorIcons.check()
                        : PhosphorIcons.tag(),
                    size: 18,
                    color: cat == selectedCategory
                        ? AppColors.dustyTeal
                        : AppColors.textMuted,
                  ),
                  const Gap(10),
                  Text(
                    TransactionCategories.localizedName(cat, l10n),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: cat == selectedCategory
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: cat == selectedCategory
                          ? AppColors.dustyTeal
                          : null,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
