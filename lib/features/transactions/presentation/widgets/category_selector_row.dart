import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';

class CategorySelectorRow extends StatelessWidget {
  const CategorySelectorRow({
    super.key,
    required this.selectedCategory,
    required this.type,
    required this.accentColor,
    required this.accentLight,
    required this.onTap,
    this.customCategories = const [],
  });

  final String? selectedCategory;
  final TransactionType type;
  final Color accentColor;
  final Color accentLight;
  final VoidCallback onTap;
  final List<TransactionCategory> customCategories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final hasSelection = selectedCategory != null;

    // Determine if the selected category is custom
    final isCustom = hasSelection &&
        !TransactionCategories.forType(type)
            .any((c) => c.name == selectedCategory);

    // Resolve icon/emoji
    final emoji = hasSelection ? _emojiForCategory(selectedCategory!, type.isIncome) : null;
    IconData? iconOverride;
    if (isCustom) {
      final custom = customCategories.firstWhere(
        (c) => c.name == selectedCategory,
        orElse: () => const TransactionCategory(name: '', icon: Icons.label_outlined),
      );
      iconOverride = custom.icon;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: hasSelection ? accentLight : cs.surface,
          border: Border.all(
            color: hasSelection ? accentColor : AppColors.borderLight,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: hasSelection ? null : AppColors.softShadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasSelection
                    ? accentColor.withValues(alpha: 0.15)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isCustom && iconOverride != null
                    ? iconOverride.fontFamily != null
                        ? Icon(iconOverride,
                            size: 18,
                            color: hasSelection
                                ? accentColor
                                : AppColors.textMuted)
                        : Text(
                            String.fromCharCode(iconOverride.codePoint),
                            style: const TextStyle(fontSize: 18),
                          )
                    : Text(
                        emoji ?? '📂',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: Text(
                hasSelection
                    ? TransactionCategories.localizedName(
                        selectedCategory!, l10n)
                    : l10n.selectCategoryPrompt,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: hasSelection ? accentColor : AppColors.textMuted,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: hasSelection ? accentColor : AppColors.textSubtle,
            ),
          ],
        ),
      ),
    );
  }

  String _emojiForCategory(String category, bool isIncome) =>
      TransactionCategories.emojiFor(category, isIncome: isIncome);
}
