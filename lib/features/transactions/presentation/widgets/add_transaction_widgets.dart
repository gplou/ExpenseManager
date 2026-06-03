import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/app_card.dart';
import 'package:expense_manager/core/widgets/numeric_keypad.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/subcategories_provider.dart';
import 'create_subcategory_dialog.dart';

// ── Type toggle (Expense / Income) ────────────────────────────────────────────

class TransactionTypeToggle extends StatelessWidget {
  const TransactionTypeToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: AppRadius.radiusLg,
      ),
      child: Row(
        children: TransactionType.values.map((type) {
          final isSelected = value == type;
          final isIncome = type.isIncome;
          final color = isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
          final iconData = isIncome
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded;
          return Expanded(
            child: Semantics(
              selected: isSelected,
              label: type.l10nLabel(l10n),
              child: GestureDetector(
                onTap: () => onChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(iconData,
                          size: 16, color: isSelected ? color : AppColors.textMuted),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        type.l10nLabel(l10n),
                        style: TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Amount display (fed from keypad controller) ───────────────────────────────

class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    super.key,
    required this.controller,
    required this.accent,
    required this.currencyCode,
    required this.error,
  });

  final AmountKeypadController controller;
  final Color accent;
  final String currencyCode;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasValue = controller.current.isNotEmpty;
        final pendingOp = controller.pendingOpSymbol;
        final previous = controller.previousText;

        return AppCard(
          variant: AppCardVariant.outlined,
          accent: accent,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
          semanticLabel:
              '${l10n.amountHint}: ${hasValue ? controller.current : "0"} $currencyCode',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (previous != null && pendingOp != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '$previous $pendingOp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: accent.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${currencySymbol(currencyCode)} ',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: accent.withValues(alpha: 0.55),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasValue ? controller.current : '0',
                        style: TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: hasValue
                              ? accent
                              : accent.withValues(alpha: 0.25),
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: AppRadius.radiusPill,
                      border: Border.all(
                          color: accent.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      currencyCode,
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: AppColors.mutedTerra,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      error!,
                      style: const TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedTerra,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Inline calendar date picker ───────────────────────────────────────────────

class InlineDatePicker extends StatelessWidget {
  const InlineDatePicker({
    super.key,
    required this.selected,
    required this.accent,
    required this.onDateChanged,
  });

  final DateTime selected;
  final Color accent;
  final ValueChanged<DateTime> onDateChanged;

  static const double _scale = 0.78;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.radiusLg,
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _scale,
            child: Transform.scale(
              scale: _scale,
              alignment: Alignment.topCenter,
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: cs.copyWith(
                    primary: accent,
                    onPrimary: AppColors.pureWhite,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: selected,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  onDateChanged: onDateChanged,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Recurring toggle compacto (chip icon) ─────────────────────────────────────

class RecurringToggleCompact extends StatelessWidget {
  const RecurringToggleCompact({
    super.key,
    required this.isRecurring,
    required this.recurrenceType,
    required this.date,
    required this.accent,
    required this.onToggle,
    required this.onChangeFrequency,
  });

  final bool isRecurring;
  final RecurrenceType? recurrenceType;
  final DateTime date;
  final Color accent;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RecurrenceType> onChangeFrequency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      toggled: isRecurring,
      label: l10n.recurringTransaction,
      child: GestureDetector(
        onTap: () => onToggle(!isRecurring),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: isRecurring
                ? AppColors.dustyTealLight
                : cs.surfaceContainerHigh,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: isRecurring ? AppColors.dustyTeal : AppColors.borderLight,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.repeat_rounded,
            size: 20,
            color: isRecurring ? AppColors.dustyTeal : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Recurring frequency picker (segmented + info) ─────────────────────────────

class RecurringFrequencyPicker extends StatelessWidget {
  const RecurringFrequencyPicker({
    super.key,
    required this.recurrenceType,
    required this.date,
    required this.accent,
    required this.onChangeFrequency,
  });

  final RecurrenceType? recurrenceType;
  final DateTime date;
  final Color accent;
  final ValueChanged<RecurrenceType> onChangeFrequency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = recurrenceType ?? RecurrenceType.monthly;
    final next = nextRecurrenceDate(date, type);
    final dayStr =
        '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
    final freq = switch (type) {
      RecurrenceType.weekly => l10n.frequencyWeek,
      RecurrenceType.monthly => l10n.frequencyMonth,
      RecurrenceType.annual => l10n.frequencyYear,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<RecurrenceType>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: RecurrenceType.weekly,
              label: Text(l10n.weekly),
              icon: const Icon(Icons.calendar_view_week_outlined, size: 16),
            ),
            ButtonSegment(
              value: RecurrenceType.monthly,
              label: Text(l10n.monthly),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
            ),
            ButtonSegment(
              value: RecurrenceType.annual,
              label: Text(l10n.yearly),
              icon: const Icon(Icons.event_repeat_outlined, size: 16),
            ),
          ],
          selected: {type},
          onSelectionChanged: (s) => onChangeFrequency(s.first),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.dustyTealLight,
            borderRadius: AppRadius.radiusMd,
          ),
          child: Row(
            children: [
              const Icon(Icons.repeat_rounded,
                  size: 14, color: AppColors.dustyTeal),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.nextRepetition(dayStr, freq),
                  style: const TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.dustyTeal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Category block ────────────────────────────────────────────────────────────

class CategoryBlock extends StatelessWidget {
  const CategoryBlock({
    super.key,
    required this.type,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.accentColor,
    required this.accentLight,
    required this.customCats,
    required this.onCategoryTap,
    required this.onSubcategorySelected,
  });

  final TransactionType type;
  final String? selectedCategory;
  final String? selectedSubcategory;
  final Color accentColor;
  final Color accentLight;
  final List<TransactionCategory> customCats;
  final VoidCallback onCategoryTap;
  final ValueChanged<String> onSubcategorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCompactRow(
          emoji: selectedCategory != null
              ? TransactionCategories.resolveEmoji(
                  selectedCategory!, type.isIncome, customCats)
              : null,
          icon: selectedCategory == null ? Icons.category_outlined : null,
          label: selectedCategory != null
              ? TransactionCategories.localizedName(selectedCategory!, l10n)
              : l10n.category,
          hasValue: selectedCategory != null,
          accent: accentColor,
          accentLight: accentLight,
          onTap: onCategoryTap,
          semanticLabel:
              '${l10n.category}: ${selectedCategory != null ? TransactionCategories.localizedName(selectedCategory!, l10n) : l10n.tutorialSkip}',
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: selectedCategory != null
              ? Padding(
                  padding: const EdgeInsets.only(
                      top: AppSpacing.sm, left: AppSpacing.xl),
                  child: AppCompactRow(
                    icon: selectedSubcategory == null
                        ? Icons.label_outline_rounded
                        : null,
                    emoji: selectedSubcategory != null ? '🏷' : null,
                    label: selectedSubcategory ?? l10n.subcategory,
                    hasValue: selectedSubcategory != null,
                    accent: accentColor,
                    accentLight: accentLight,
                    onTap: () async {
                      final sub = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => SubcategoryPickerSheet(
                          selected: selectedSubcategory,
                          category: selectedCategory!,
                          type: type,
                          accentColor: accentColor,
                          accentLight: accentLight,
                        ),
                      );
                      if (sub != null) onSubcategorySelected(sub);
                    },
                    semanticLabel:
                        '${l10n.subcategory}: ${selectedSubcategory ?? ""}',
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Details block: description field ─────────────────────────────────────────

class DetailsBlock extends StatelessWidget {
  const DetailsBlock({
    super.key,
    required this.descriptionController,
    required this.descriptionFocus,
  });

  final TextEditingController descriptionController;
  final FocusNode descriptionFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.edit_note_rounded,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextFormField(
              controller: descriptionController,
              focusNode: descriptionFocus,
              maxLines: 1,
              maxLength: 100,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => descriptionFocus.unfocus(),
              onEditingComplete: descriptionFocus.unfocus,
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.descriptionOptional,
                hintStyle: const TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subcategory picker sheet ──────────────────────────────────────────────────

class SubcategoryPickerSheet extends ConsumerWidget {
  const SubcategoryPickerSheet({
    super.key,
    required this.selected,
    required this.category,
    required this.type,
    required this.accentColor,
    required this.accentLight,
  });

  final String? selected;
  final String category;
  final TransactionType type;
  final Color accentColor;
  final Color accentLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final asyncSubs = ref.watch(
      subcategoriesProvider((category: category, type: type)),
    );
    final subcategories = asyncSubs.value ?? [];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Text(
                  l10n.subcategory.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    l10n.tutorialSkip,
                    style: TextStyle(color: accentColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ...subcategories.map((name) {
                  final isSelected = selected == name;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.only(
                        left: 14, top: 4, bottom: 4, right: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? accentLight : cs.surface,
                      borderRadius: AppRadius.radiusPill,
                      border: Border.all(
                        color:
                            isSelected ? accentColor : AppColors.borderLight,
                        width: 1.5,
                      ),
                      boxShadow:
                          isSelected ? null : AppColors.softShadowSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context, name);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? accentColor
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact().ignore();
                            _confirmDeleteSubcategory(context, ref, name);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isSelected
                                      ? accentColor
                                      : AppColors.textMuted)
                                  .withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: isSelected
                                  ? accentColor
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () async {
                    final newName = await showDialog<String>(
                      context: context,
                      builder: (_) => CreateSubcategoryDialog(
                        category: category,
                        type: type,
                      ),
                    );
                    if (newName != null && context.mounted) {
                      Navigator.pop(context, newName);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: AppRadius.radiusPill,
                      border: Border.all(
                        color: AppColors.dustyTeal,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 14, color: AppColors.dustyTeal),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l10n.newSubcategory,
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
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSubcategory(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteSubcategoryConfirm),
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
    await ref
        .read(subcategoriesRepositoryProvider)
        .remove(category, type, name);
    ref.invalidate(
      subcategoriesProvider((category: category, type: type)),
    );
  }
}

// ── Step indicator (two segmented capsule bars) ───────────────────────────────

class TransactionStepIndicator extends StatelessWidget {
  const TransactionStepIndicator({
    super.key,
    required this.currentStep,
    required this.accent,
  });

  final int currentStep;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StepBar(active: true, accent: accent)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: _StepBar(active: currentStep >= 1, accent: accent)),
      ],
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.active, required this.accent});

  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: 4,
      decoration: BoxDecoration(
        color: active ? accent : AppColors.borderLight,
        borderRadius: AppRadius.radiusPill,
      ),
    );
  }
}

// ── Amount pill (AppBar action in step 2) ─────────────────────────────────────

class AmountPill extends StatelessWidget {
  const AmountPill({
    super.key,
    required this.controller,
    required this.type,
    required this.accent,
    required this.accentLight,
    required this.currencyCode,
    required this.onTap,
  });

  final AmountKeypadController controller;
  final TransactionType type;
  final Color accent;
  final Color accentLight;
  final String currencyCode;
  final VoidCallback onTap;

  String _format(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final value = controller.resolve() ?? 0;
        final amountStr = _format(value);
        final icon = type.isIncome
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded;
        return Semantics(
          button: true,
          label: '${type.isIncome ? "+" : "-"}$amountStr $currencyCode',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.radiusPill,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentLight,
                  borderRadius: AppRadius.radiusPill,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      '${currencySymbol(currencyCode)} $amountStr',
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_rounded,
                      size: 11,
                      color: accent.withValues(alpha: 0.65),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
