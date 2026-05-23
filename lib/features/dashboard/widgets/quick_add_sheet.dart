import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/router.dart';
import '../../../core/providers/currency_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../../../l10n/app_localizations.dart';
import '../../subscription/subscription_provider.dart';
import '../../transactions/domain/transaction_categories.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/providers/custom_categories_provider.dart';
import '../../transactions/presentation/providers/transactions_provider.dart';
import '../../transactions/presentation/widgets/category_picker_sheet.dart';
import '../../transactions/presentation/widgets/recent_categories_strip.dart';

/// Bottom sheet unificado: 4 atajos (Manual / Voz / Foto / Chat) arriba +
/// captura inmediata de gasto abajo (importe + categoría + save).
///
/// Diseñado para reemplazar el SpeedDial radial cuando el tutorial no está
/// activo. Propaga callbacks para que el llamador maneje los flujos de IA.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    required this.onVoiceTap,
    required this.onCameraTap,
  });

  final VoidCallback onVoiceTap;
  final VoidCallback onCameraTap;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  late final AmountKeypadController _keypad;
  TransactionType _type = TransactionType.expense;
  String? _selectedCategory;
  bool _isSaving = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _keypad = AmountKeypadController();
  }

  @override
  void dispose() {
    _keypad.dispose();
    super.dispose();
  }

  Color get _accent => _type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
  Color get _accentLight =>
      _type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final amount = _keypad.resolve();
    if (amount == null || amount <= 0) {
      setState(() => _amountError = l10n.invalidAmount);
      HapticFeedback.heavyImpact();
      return;
    }
    if (_selectedCategory == null) {
      context.showSnackbar(l10n.selectCategory, isError: true);
      return;
    }
    setState(() {
      _isSaving = true;
      _amountError = null;
    });
    try {
      final currency = ref.read(currencyProvider).value ?? 'EUR';
      final tx = TransactionModel(
        id: '',
        userId: '',
        amount: amount,
        type: _type,
        category: _selectedCategory!,
        subcategory: null,
        description: null,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        currency: currency,
      );
      await ref.read(transactionsNotifierProvider.notifier).create(tx);
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      developer.log('QuickAddSheet save failed', error: e, stackTrace: st);
      if (mounted) {
        context.showSnackbar(l10n.errorSaving, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickCategory() async {
    final selected = await showCategoryPickerSheet(
      context,
      ref,
      type: _type,
      selectedCategory: _selectedCategory,
      accentColor: _accent,
      accentLight: _accentLight,
    );
    if (selected != null && mounted) {
      setState(() => _selectedCategory = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPro = ref.watch(isProProvider);
    final customCats = ref.watch(
      customCategoriesSyncProvider.select((m) => m[_type] ?? []),
    );
    final currency = ref.watch(currencyProvider).value ?? 'EUR';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Atajos: Voz / Foto / Chat ──────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _ShortcutButton(
                        icon: Icons.mic_rounded,
                        label: l10n.labelVoice,
                        proGated: !isPro,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onVoiceTap();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ShortcutButton(
                        icon: Icons.camera_alt_rounded,
                        label: l10n.labelPhoto,
                        proGated: !isPro,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onCameraTap();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ShortcutButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: l10n.labelChat,
                        proGated: !isPro,
                        onTap: () {
                          Navigator.of(context).pop();
                          if (!isPro) {
                            context.push(AppRoutes.pro);
                          } else {
                            context.push(AppRoutes.chat);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Type toggle ────────────────────────────────────────────
                _MiniTypeToggle(
                  type: _type,
                  onChanged: (t) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _type = t;
                      _selectedCategory = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Amount display ─────────────────────────────────────────
                ListenableBuilder(
                  listenable: _keypad,
                  builder: (context, _) {
                    final hasValue = _keypad.current.isNotEmpty;
                    return AppCard(
                      variant: AppCardVariant.outlined,
                      accent: _accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${currencySymbol(currency)} ',
                                style: TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _accent.withValues(alpha: 0.55),
                                ),
                              ),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    hasValue ? _keypad.current : '0',
                                    style: TextStyle(
                                      fontFamily: 'GeneralSans',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: hasValue
                                          ? _accent
                                          : _accent.withValues(alpha: 0.25),
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_amountError != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _amountError!,
                              style: const TextStyle(
                                fontFamily: 'GeneralSans',
                                fontSize: 12,
                                color: AppColors.mutedTerra,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Recent categories + manual picker ──────────────────────
                RecentCategoriesStrip(
                  type: _type,
                  selected: _selectedCategory,
                  accentColor: _accent,
                  accentLight: _accentLight,
                  onSelect: (cat) =>
                      setState(() => _selectedCategory = cat),
                ),
                AppCompactRow(
                  emoji: _selectedCategory != null
                      ? TransactionCategories.resolveEmoji(
                          _selectedCategory!,
                          _type.isIncome,
                          customCats)
                      : null,
                  icon: _selectedCategory == null
                      ? Icons.category_outlined
                      : null,
                  label: _selectedCategory != null
                      ? TransactionCategories.localizedName(
                          _selectedCategory!, l10n)
                      : l10n.category,
                  hasValue: _selectedCategory != null,
                  accent: _accent,
                  accentLight: _accentLight,
                  onTap: _pickCategory,
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Numeric keypad ─────────────────────────────────────────
                NumericKeypad(
                  controller: _keypad,
                  accent: _accent,
                  canSubmit: !_isSaving,
                  submitLabel: _type.isIncome
                      ? l10n.saveIncome
                      : l10n.saveExpense,
                  onSubmit: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.proGated = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool proGated;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: cs.outline, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: cs.onSurface.withValues(alpha: 0.85),
                  ),
                  if (proGated)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warmAmber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.pureWhite,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.85),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTypeToggle extends StatelessWidget {
  const _MiniTypeToggle({required this.type, required this.onChanged});

  final TransactionType type;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: AppRadius.radiusMd,
      ),
      child: Row(
        children: TransactionType.values.map((t) {
          final isSel = type == t;
          final color = t.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
          final icon = t.isIncome
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSel,
              label: t.l10nLabel(l10n),
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? cs.surface : Colors.transparent,
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          size: 16,
                          color: isSel ? color : AppColors.textMuted),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        t.l10nLabel(l10n),
                        style: TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSel ? color : AppColors.textMuted,
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
