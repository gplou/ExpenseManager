import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/hidden_builtin_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/create_category_dialog.dart';

/// Opens a modal bottom sheet with a grid of categories.
/// Returns the selected category DB key, or `null` if dismissed.
Future<String?> showCategoryPickerSheet(
  BuildContext context,
  WidgetRef ref, {
  required TransactionType type,
  required String? selectedCategory,
  required Color accentColor,
  required Color accentLight,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CategoryPickerContent(
      type: type,
      selectedCategory: selectedCategory,
      accentColor: accentColor,
      accentLight: accentLight,
    ),
  );
}

class _CategoryPickerContent extends ConsumerWidget {
  const _CategoryPickerContent({
    required this.type,
    required this.selectedCategory,
    required this.accentColor,
    required this.accentLight,
  });

  final TransactionType type;
  final String? selectedCategory;
  final Color accentColor;
  final Color accentLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;

    final customCats = ref.watch(customCategoriesSyncProvider);
    final hiddenBuiltIns = ref.watch(hiddenBuiltInCategoriesProvider);
    final builtInCategories = TransactionCategories.forType(type)
        .where((c) => !(hiddenBuiltIns[type]?.contains(c.name) ?? false))
        .toList();
    final allCategories = [
      ...builtInCategories,
      ...(customCats[type] ?? []),
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(16),
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  l10n.category.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final newName = await showDialog<String>(
                      context: context,
                      builder: (_) => CreateCategoryDialog(type: type),
                    );
                    if (newName != null && context.mounted) {
                      Navigator.pop(context, newName);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 14, color: AppColors.dustyTeal),
                      const Gap(4),
                      Text(
                        l10n.newCategory,
                        style: const TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dustyTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          // Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: allCategories.map((cat) {
                final isSelected = selectedCategory == cat.name;
                final isCustom = !TransactionCategories.forType(type)
                    .any((c) => c.name == cat.name);
                final emoji = _emojiForCategory(cat.name, type.isIncome);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, cat.name);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? accentLight : cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isSelected ? accentColor : AppColors.borderLight,
                        width: 1.5,
                      ),
                      boxShadow: isSelected ? null : AppColors.softShadowSm,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isCustom && cat.emojiOverride != null)
                                Text(cat.emojiOverride!,
                                    style: const TextStyle(fontSize: 24))
                              else if (isCustom)
                                Icon(cat.icon,
                                    size: 24,
                                    color: isSelected
                                        ? accentColor
                                        : AppColors.textMuted)
                              else
                                Text(emoji,
                                    style: const TextStyle(fontSize: 24)),
                              const Gap(6),
                              Text(
                                TransactionCategories.localizedName(
                                    cat.name, l10n),
                                style: TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? accentColor
                                      : AppColors.textMuted,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              _confirmDeleteCategory(
                                context,
                                ref,
                                cat.name,
                                isCustom: isCustom,
                              );
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.textMuted.withValues(alpha: 0.12),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    String name, {
    required bool isCustom,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('"$name"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.mutedTerra),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (isCustom) {
      await ref.read(customCategoriesProvider.notifier).remove(type, name);
    } else {
      await ref
          .read(hiddenBuiltInCategoriesProvider.notifier)
          .hide(type, name);
    }
  }

  String _emojiForCategory(String category, bool isIncome) =>
      TransactionCategories.emojiFor(category, isIncome: isIncome);
}
