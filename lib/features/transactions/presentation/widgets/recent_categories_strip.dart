import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
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

/// Tira horizontal de categorías frecuentes para selección rápida (1 tap).
///
/// Si hay <2 categorías recientes, no se renderiza (evita ruido visual en
/// usuarios nuevos sin historial).
class RecentCategoriesStrip extends ConsumerWidget {
  const RecentCategoriesStrip({
    super.key,
    required this.type,
    required this.selected,
    required this.onSelect,
    required this.accentColor,
    required this.accentLight,
  });

  final TransactionType type;
  final String? selected;
  final ValueChanged<String> onSelect;
  final Color accentColor;
  final Color accentLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncRecent = ref.watch(recentCategoriesProvider(type));
    final customCats = ref.watch(customCategoriesSyncProvider)[type] ?? [];

    final recent = asyncRecent.value ?? const [];
    if (recent.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: recent.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, i) {
            final name = recent[i];
            final isSelected = selected == name;
            final emoji = TransactionCategories.resolveEmoji(
                name, type.isIncome, customCats);
            final label = TransactionCategories.localizedName(name, l10n);

            return _RecentChip(
              key: ValueKey(name),
              emoji: emoji,
              label: label,
              isSelected: isSelected,
              accentColor: accentColor,
              accentLight: accentLight,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(name);
              },
            );
          },
        ),
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    super.key,
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.accentLight,
    required this.onTap,
  });

  final String emoji;
  final String label;
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
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
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
              Text(emoji, style: const TextStyle(fontSize: AppEmojiSize.small)),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 12,
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
