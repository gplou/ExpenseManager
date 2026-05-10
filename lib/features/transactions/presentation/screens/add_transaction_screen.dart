import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/ad_banner_footer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/numeric_keypad.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../subscription/subscription_provider.dart';
import '../../data/recurring_transactions_repository.dart';
import '../../data/subcategories_repository.dart';
import '../../domain/parsed_voice_transaction.dart';
import '../../domain/recurring_transaction_model.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/subcategories_provider.dart';
import '../providers/transactions_provider.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/create_subcategory_dialog.dart';
import '../widgets/recent_categories_strip.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction, this.voiceData});

  final TransactionModel? transaction;
  final ParsedVoiceTransaction? voiceData;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

// ── Recurring frequency picker (segmented + info) ────────────────────────────

class _RecurringFrequencyPicker extends StatelessWidget {
  const _RecurringFrequencyPicker({
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
                    fontFamily: 'Sora',
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

// ── Screen ────────────────────────────────────────────────────────────────────

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _type;
  late final AmountKeypadController _keypadController;
  late final TextEditingController _descriptionController;
  final FocusNode _descriptionFocus = FocusNode();
  String? _selectedCategory;
  String? _selectedSubcategory;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _isRecurring = false;
  RecurrenceType? _recurrenceType;
  String? _amountError;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    final v = widget.voiceData;
    _type = t?.type ?? v?.type ?? TransactionType.expense;
    _keypadController = AmountKeypadController();
    final initialAmount = t?.amount ?? v?.amount;
    if (initialAmount != null && initialAmount > 0) {
      _keypadController.setValue(initialAmount);
    }
    _descriptionController =
        TextEditingController(text: t?.description ?? v?.description ?? '');
    _selectedCategory = t?.category ?? v?.category;
    _selectedSubcategory = t?.subcategory ?? v?.subcategory;
    _selectedDate = t?.date ?? v?.date ?? DateTime.now();

    if (v?.isRecurring == true) {
      _isRecurring = true;
      _recurrenceType = switch (v?.recurrenceType) {
        'weekly' => RecurrenceType.weekly,
        'annual' => RecurrenceType.annual,
        _ => RecurrenceType.monthly,
      };
    }
    if (v?.subcategory != null && v?.category != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final repo = ref.read(subcategoriesRepositoryProvider);
          final existing = await repo.getForCategory(v!.category, v.type);
          if (!existing.contains(v.subcategory)) {
            await repo.add(v.category, v.type, v.subcategory!);
          }
          ref.invalidate(subcategoriesProvider(
            (category: v.category, type: v.type),
          ));
        } catch (e, st) {
          developer.log(
            'Failed to ensure voice subcategory',
            error: e,
            stackTrace: st,
          );
        }
      });
    }
    if (t?.recurringTransactionId != null) {
      _isRecurring = true;
      _loadRecurrenceType(t!.recurringTransactionId!);
    }
  }

  Future<void> _loadRecurrenceType(String recurringId) async {
    final recurring = await ref
        .read(recurringTransactionsRepositoryProvider)
        .getById(recurringId);
    if (recurring != null && mounted) {
      setState(() => _recurrenceType = recurring.recurrenceType);
    }
  }

  @override
  void dispose() {
    _keypadController.dispose();
    _descriptionController.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<void> _openCategoryPicker() async {
    final accentColor =
        _type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight =
        _type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;
    final selected = await showCategoryPickerSheet(
      context,
      ref,
      type: _type,
      selectedCategory: _selectedCategory,
      accentColor: accentColor,
      accentLight: accentLight,
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCategory = selected;
        _selectedSubcategory = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final cs = context.colors;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: cs.copyWith(
            primary: AppColors.dustyTeal,
            onPrimary: AppColors.pureWhite,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final currentCurrency = ref.read(currencyProvider).value ?? 'EUR';
    final amount = _keypadController.resolve();

    if (amount == null || amount <= 0) {
      setState(() => _amountError = l10n.invalidAmount);
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _amountError = null);

    if (_selectedCategory == null) {
      context.showSnackbar(l10n.selectCategory, isError: true);
      return;
    }
    if (_isRecurring && _recurrenceType == null) {
      context.showSnackbar(l10n.selectFrequency, isError: true);
      return;
    }

    final desc = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        final updated = widget.transaction!.copyWith(
          amount: amount,
          type: _type,
          category: _selectedCategory!,
          subcategory: _selectedSubcategory,
          description: desc,
          date: _selectedDate,
          currency: currentCurrency,
        );

        final existingRecurringId = widget.transaction!.recurringTransactionId;
        if (_isRecurring && _recurrenceType != null) {
          final nextDate = nextRecurrenceDate(_selectedDate, _recurrenceType!);
          if (existingRecurringId != null) {
            await ref
                .read(recurringTransactionsRepositoryProvider)
                .updateRecurring(
                  id: existingRecurringId,
                  amount: amount,
                  type: _type,
                  category: _selectedCategory!,
                  subcategory: _selectedSubcategory,
                  description: desc,
                  recurrenceType: _recurrenceType!,
                  nextOccurrence: nextDate,
                );
            await ref
                .read(transactionsNotifierProvider.notifier)
                .update(updated);
          } else {
            final recurringId = await ref
                .read(recurringTransactionsRepositoryProvider)
                .createRecurring(
                  amount: amount,
                  type: _type,
                  category: _selectedCategory!,
                  subcategory: _selectedSubcategory,
                  description: desc,
                  recurrenceType: _recurrenceType!,
                  nextOccurrence: nextDate,
                );
            await ref
                .read(transactionsNotifierProvider.notifier)
                .update(updated.copyWith(recurringTransactionId: recurringId));
          }
        } else {
          if (existingRecurringId != null) {
            await ref
                .read(recurringTransactionsRepositoryProvider)
                .deleteRecurring(existingRecurringId);
          }
          await ref
              .read(transactionsNotifierProvider.notifier)
              .update(updated.copyWith(recurringTransactionId: null));
        }
      } else {
        String? recurringId;
        if (_isRecurring && _recurrenceType != null) {
          final nextDate = nextRecurrenceDate(_selectedDate, _recurrenceType!);
          recurringId = await ref
              .read(recurringTransactionsRepositoryProvider)
              .createRecurring(
                amount: amount,
                type: _type,
                category: _selectedCategory!,
                subcategory: _selectedSubcategory,
                description: desc,
                recurrenceType: _recurrenceType!,
                nextOccurrence: nextDate,
              );
        }
        final transaction = TransactionModel(
          id: '',
          userId: '',
          amount: amount,
          type: _type,
          category: _selectedCategory!,
          subcategory: _selectedSubcategory,
          description: desc,
          date: _selectedDate,
          createdAt: DateTime.now(),
          recurringTransactionId: recurringId,
          currency: currentCurrency,
        );
        await ref
            .read(transactionsNotifierProvider.notifier)
            .create(transaction);
      }
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      developer.log(
        _isEditing ? 'Update transaction failed' : 'Create transaction failed',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        context.showSnackbar(
          _isEditing ? l10n.errorUpdating : l10n.errorSaving,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final t = widget.transaction!;
    final isRecurring = t.recurringTransactionId != null;
    final String confirmMessage;
    if (isRecurring) {
      confirmMessage = t.type.isExpense
          ? l10n.deleteRecurringExpenseConfirm
          : l10n.deleteRecurringIncomeConfirm;
    } else {
      confirmMessage = l10n.deleteTransactionConfirm;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(confirmMessage),
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
    if (confirmed != true || !mounted) return;
    await ref
        .read(transactionsNotifierProvider.notifier)
        .delete(widget.transaction!.id, recurringTransactionId: widget.transaction!.recurringTransactionId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customCats = ref.watch(
      customCategoriesSyncProvider.select((m) => m[_type] ?? []),
    );

    final accentColor =
        _type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight =
        _type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

    final isPro = ref.watch(isProProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editTransaction : l10n.newTransaction),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: l10n.delete,
              onPressed: _delete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.mutedTerra,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListenableBuilder(
                listenable: _descriptionFocus,
                builder: (context, _) {
                  final focused = _descriptionFocus.hasFocus;
                  final label = _isEditing
                      ? l10n.saveChanges
                      : (_type.isIncome ? l10n.saveIncome : l10n.saveExpense);
                  if (focused) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                          AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(label),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor),
                      ),
                    );
                  }
                  return NumericKeypad(
                    controller: _keypadController,
                    accent: accentColor,
                    submitLabel: label,
                    canSubmit: !_isSaving,
                    onSubmit: _save,
                  );
                },
              ),
              if (!isPro) const AdBannerFooter(),
            ],
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeToggle(
                value: _type,
                onChanged: (next) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _type = next;
                    _selectedCategory = null;
                    _selectedSubcategory = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _AmountDisplay(
                controller: _keypadController,
                accent: accentColor,
                currencyCode: ref.watch(currencyProvider).value ?? 'EUR',
                error: _amountError,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Categorías frecuentes (1-tap selection).
              RecentCategoriesStrip(
                type: _type,
                selected: _selectedCategory,
                accentColor: accentColor,
                accentLight: accentLight,
                onSelect: (cat) {
                  setState(() {
                    _selectedCategory = cat;
                    _selectedSubcategory = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Category + Date en la misma fila
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _CategoryBlock(
                      type: _type,
                      selectedCategory: _selectedCategory,
                      selectedSubcategory: _selectedSubcategory,
                      accentColor: accentColor,
                      accentLight: accentLight,
                      customCats: customCats,
                      onCategoryTap: _openCategoryPicker,
                      onSubcategorySelected: (sub) =>
                          setState(() => _selectedSubcategory = sub),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: _DateQuickPicker(
                      selected: _selectedDate,
                      accent: accentColor,
                      accentLight: accentLight,
                      onSelect: (d) => setState(() => _selectedDate = d),
                      onPickCustom: _pickDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description + Recurring en la misma fila
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _DetailsBlock(
                      descriptionController: _descriptionController,
                      descriptionFocus: _descriptionFocus,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _RecurringToggleCompact(
                    isRecurring: _isRecurring,
                    recurrenceType: _recurrenceType,
                    date: _selectedDate,
                    accent: accentColor,
                    onToggle: (v) => setState(() {
                      _isRecurring = v;
                      _recurrenceType = v ? RecurrenceType.monthly : null;
                    }),
                    onChangeFrequency: (t) =>
                        setState(() => _recurrenceType = t),
                  ),
                ],
              ),

              // Frecuencia — solo visible cuando recurring está activo
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _isRecurring
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _RecurringFrequencyPicker(
                          recurrenceType: _recurrenceType,
                          date: _selectedDate,
                          accent: accentColor,
                          onChangeFrequency: (t) =>
                              setState(() => _recurrenceType = t),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type toggle (Expense / Income) ────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

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
              button: true,
              selected: isSelected,
              label: type.l10nLabel(l10n),
              child: GestureDetector(
                onTap: () => onChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.surface : Colors.transparent,
                    borderRadius: AppRadius.radiusMd,
                    boxShadow: isSelected ? AppColors.softShadowSm : AppElevation.e0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        iconData,
                        size: 18,
                        color: isSelected ? color : AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        type.l10nLabel(l10n),
                        style: TextStyle(
                          fontFamily: 'Sora',
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

// ── Amount display (no editable, viene del keypad) ────────────────────────────

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
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
                      fontFamily: 'Sora',
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
                      fontFamily: 'Sora',
                      fontSize: 22,
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
                          fontFamily: 'Sora',
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
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
                        fontFamily: 'Sora',
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
                        fontFamily: 'Sora',
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

// ── Date quick picker (Today / Yesterday / Other) ────────────────────────────

class _DateQuickPicker extends StatelessWidget {
  const _DateQuickPicker({
    required this.selected,
    required this.accent,
    required this.accentLight,
    required this.onSelect,
    required this.onPickCustom,
  });

  final DateTime selected;
  final Color accent;
  final Color accentLight;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPickCustom;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = _normalize(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final selectedDay = _normalize(selected);

    final isToday = selectedDay == today;
    final isYesterday = selectedDay == yesterday;
    final isOther = !isToday && !isYesterday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateChip(
          label: l10n.today,
          active: isToday,
          accent: accent,
          accentLight: accentLight,
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(today);
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        _DateChip(
          label: l10n.yesterday,
          active: isYesterday,
          accent: accent,
          accentLight: accentLight,
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(yesterday);
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        _DateChip(
          label: isOther ? selected.formattedDate : '…',
          icon: Icons.calendar_today_rounded,
          active: isOther,
          accent: accent,
          accentLight: accentLight,
          onTap: onPickCustom,
        ),
      ],
    );
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.active,
    required this.accent,
    required this.accentLight,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final Color accent;
  final Color accentLight;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: active ? accentLight : cs.surface,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: active ? accent : AppColors.borderLight,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: active ? accent : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? accent : AppColors.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recurring toggle compacto (chip icon + switch) ───────────────────────────

class _RecurringToggleCompact extends StatelessWidget {
  const _RecurringToggleCompact({
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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

// ── Category block: categoría full-width + subcategoría indentada ─────────────

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
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
                        builder: (_) => _SubcategoryPickerSheet(
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

// ── Details block: descripción con label visible ───────────────────────────────

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xl + AppSpacing.sm,
                top: AppSpacing.xs + 2),
            child: Text(
              l10n.descriptionOptional.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextFormField(
            controller: descriptionController,
            focusNode: descriptionFocus,
            maxLines: 1,
            maxLength: 50,
            textInputAction: TextInputAction.done,
            onTapOutside: (_) => descriptionFocus.unfocus(),
            onEditingComplete: descriptionFocus.unfocus,
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              icon: const Icon(Icons.edit_note_rounded,
                  color: AppColors.textMuted),
              hintText: '—',
              hintStyle: const TextStyle(
                fontFamily: 'Sora',
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
        ],
      ),
    );
  }
}

// ── Subcategory picker sheet ──────────────────────────────────────────────────

class _SubcategoryPickerSheet extends ConsumerWidget {
  const _SubcategoryPickerSheet({
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
                    fontFamily: 'Sora',
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
                                fontFamily: 'Sora',
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
                            HapticFeedback.heavyImpact();
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
                            fontFamily: 'Sora',
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
