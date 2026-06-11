import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/hidden_builtin_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

/// Top 5 categorías más usadas para un tipo (income/expense), ordenadas por
/// frecuencia descendente. Calculado a partir de `allTransactionsProvider`.
final recentCategoriesProvider = FutureProvider.autoDispose
    .family<List<String>, TransactionType>((ref, type) async {
  final all = await ref.watch(allTransactionsProvider.future);
  final counts = <String, int>{};
  for (final t in all.where((t) => t.type == type)) {
    counts[t.category] = (counts[t.category] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).map((e) => e.key).toList();
});

/// Categorías de acceso rápido: las recientes primero y, si no llegan a
/// [_maxQuickCategories], se rellena con custom + built-in visibles para que
/// un usuario sin historial también pueda elegir con 1 tap.
const int _maxQuickCategories = 8;

final quickCategoriesProvider = FutureProvider.autoDispose
    .family<List<String>, TransactionType>((ref, type) async {
  final recent = await ref.watch(recentCategoriesProvider(type).future);
  final custom = ref.watch(customCategoriesSyncProvider)[type] ?? const [];
  final hidden = ref.watch(hiddenBuiltInCategoriesProvider)[type];

  final result = <String>[...recent];
  final fallback = <String>[
    ...custom.map((c) => c.name),
    ...TransactionCategories.forType(type)
        .where((c) => !(hidden?.contains(c.name) ?? false))
        .map((c) => c.name),
  ];
  for (final name in fallback) {
    if (result.length >= _maxQuickCategories) break;
    if (!result.contains(name)) result.add(name);
  }
  return result;
});

/// Tira horizontal de categorías para selección con 1 tap, con un chip final
/// "Más" que abre el picker completo. La categoría seleccionada siempre es
/// visible (se antepone si no estaba en la lista).
class QuickCategoryStrip extends ConsumerWidget {
  const QuickCategoryStrip({
    super.key,
    required this.type,
    required this.selected,
    required this.onSelect,
    required this.onMore,
    required this.accentColor,
    required this.accentLight,
  });

  final TransactionType type;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onMore;
  final Color accentColor;
  final Color accentLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncQuick = ref.watch(quickCategoriesProvider(type));
    final customCats = ref.watch(customCategoriesSyncProvider)[type] ?? [];

    final names = [...asyncQuick.value ?? const <String>[]];
    if (selected != null && !names.contains(selected)) {
      names.insert(0, selected!);
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: names.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == names.length) {
            return _QuickChip(
              key: const ValueKey('quick-chip-more'),
              icon: Icons.grid_view_rounded,
              label: l10n.more,
              semanticLabel: l10n.allCategories,
              isSelected: false,
              accentColor: accentColor,
              accentLight: accentLight,
              onTap: () {
                HapticFeedback.selectionClick();
                onMore();
              },
            );
          }
          final name = names[i];
          return _QuickChip(
            key: ValueKey(name),
            emoji: TransactionCategories.resolveEmoji(
                name, type.isIncome, customCats),
            label: TransactionCategories.localizedName(name, l10n),
            isSelected: selected == name,
            accentColor: accentColor,
            accentLight: accentLight,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(name);
            },
          );
        },
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    super.key,
    this.emoji,
    this.icon,
    required this.label,
    this.semanticLabel,
    required this.isSelected,
    required this.accentColor,
    required this.accentLight,
    required this.onTap,
  });

  final String? emoji;
  final IconData? icon;
  final String label;
  final String? semanticLabel;
  final bool isSelected;
  final Color accentColor;
  final Color accentLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel ?? label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? accentLight : cs.surface,
            borderRadius: AppRadius.radiusPill,
            border: Border.all(
              color: isSelected ? accentColor : AppColors.borderLight,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null)
                Text(emoji!,
                    style: const TextStyle(fontSize: AppEmojiSize.small))
              else if (icon != null)
                Icon(icon, size: 15,
                    color: isSelected ? accentColor : AppColors.textMuted),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? accentColor : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
