import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/app_card.dart';
import 'package:expense_manager/core/widgets/numeric_keypad.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
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
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
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
                      fontSize: 26,
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
                          fontSize: 44,
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

// ── Detail pill (fecha / nota / repetir / subcategoría) ───────────────────────
//
// Disclosure progresivo: cada píldora muestra el valor actual y abre un sheet
// compacto al tocarla. Mantiene la pantalla principal mínima sin esconder
// funcionalidad.

class DetailPill extends StatelessWidget {
  const DetailPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    required this.accent,
    required this.accentLight,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Cuando la píldora tiene un valor no-default (nota escrita, recurrencia
  /// activa, fecha ≠ hoy…) se tinta con el accent para señalarlo.
  final bool active;
  final Color accent;
  final Color accentLight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? accentLight : cs.surfaceContainerHigh,
            borderRadius: AppRadius.radiusPill,
            border: Border.all(
              color: active ? accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16,
                  color: active ? accent : AppColors.textMuted),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? accent : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta corta y legible para la píldora de fecha: Hoy / Ayer / "12 mar".
String relativeDateLabel(BuildContext context, DateTime date) {
  final l10n = AppLocalizations.of(context);
  final now = clock.now();
  final d = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (d == today) return l10n.relToday;
  if (d == today.subtract(const Duration(days: 1))) return l10n.relYesterday;
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.MMMd(locale).format(date);
}

// ── Quick date sheet ──────────────────────────────────────────────────────────

Future<DateTime?> showQuickDateSheet(
  BuildContext context, {
  required DateTime selected,
  required Color accent,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      final cs = Theme.of(ctx).colorScheme;
      final now = clock.now();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Text(
                  l10n.date.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                _QuickDateChip(
                  label: l10n.relToday,
                  accent: accent,
                  onTap: () => Navigator.pop(ctx, now),
                ),
                const SizedBox(width: AppSpacing.sm),
                _QuickDateChip(
                  label: l10n.relYesterday,
                  accent: accent,
                  onTap: () => Navigator.pop(
                      ctx, now.subtract(const Duration(days: 1))),
                ),
              ],
            ),
          ),
          Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: cs.copyWith(
                primary: accent,
                onPrimary: AppColors.pureWhite,
              ),
            ),
            child: CalendarDatePicker(
              initialDate: selected,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onDateChanged: (d) => Navigator.pop(ctx, d),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      );
    },
  );
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: AppRadius.radiusPill,
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'GeneralSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Note sheet ────────────────────────────────────────────────────────────────

/// Devuelve el texto (puede ser vacío para borrar la nota) o null si se
/// descartó sin guardar.
Future<String?> showNoteSheet(
  BuildContext context, {
  required String initial,
  required Color accent,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _NoteSheet(initial: initial, accent: accent),
  );
}

/// El controller vive en el State para que se libere en dispose(), es decir,
/// cuando la ruta ya salió del árbol — liberarlo en whenComplete del pop
/// deja al EditableText usando un controller muerto durante la animación de
/// cierre del sheet.
class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.initial, required this.accent});

  final String initial;
  final Color accent;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.note.toUpperCase(),
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
                onPressed: () =>
                    Navigator.pop(context, _controller.text.trim()),
                child: Text(l10n.save, style: TextStyle(color: widget.accent)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 1,
            maxLength: 100,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
            decoration: InputDecoration(
              hintText: l10n.descriptionHint,
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recurrence sheet ──────────────────────────────────────────────────────────

/// Resultado del sheet de recurrencia. `type == null` significa "no repetir".
/// Se envuelve en una clase para distinguirlo de un cierre sin selección.
class RecurrenceChoice {
  const RecurrenceChoice(this.type);
  final RecurrenceType? type;
}

Future<RecurrenceChoice?> showRecurrenceSheet(
  BuildContext context, {
  required RecurrenceType? current,
  required DateTime date,
  required Color accent,
}) {
  return showModalBottomSheet<RecurrenceChoice>(
    context: context,
    useSafeArea: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      final options = <(RecurrenceType?, IconData, String)>[
        (null, Icons.block_rounded, l10n.noRepeat),
        (RecurrenceType.weekly, Icons.calendar_view_week_outlined, l10n.weekly),
        (RecurrenceType.monthly, Icons.calendar_month_outlined, l10n.monthly),
        (RecurrenceType.annual, Icons.event_repeat_outlined, l10n.yearly),
      ];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Text(
                  l10n.recurringTransaction.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (type, icon, label) in options)
            _RecurrenceOption(
              icon: icon,
              label: label,
              subtitle: type == null
                  ? null
                  : _nextRepetitionLabel(l10n, date, type),
              selected: current == type,
              accent: accent,
              onTap: () => Navigator.pop(ctx, RecurrenceChoice(type)),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      );
    },
  );
}

String _nextRepetitionLabel(
  AppLocalizations l10n,
  DateTime date,
  RecurrenceType type,
) {
  final next = nextRecurrenceDate(date, type);
  final dayStr =
      '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
  final freq = switch (type) {
    RecurrenceType.weekly => l10n.frequencyWeek,
    RecurrenceType.monthly => l10n.frequencyMonth,
    RecurrenceType.annual => l10n.frequencyYear,
  };
  return l10n.nextRepetition(dayStr, freq);
}

class _RecurrenceOption extends StatelessWidget {
  const _RecurrenceOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, size: 20,
                  color: selected ? accent : AppColors.textMuted),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? accent : cs.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 20, color: accent),
            ],
          ),
        ),
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
