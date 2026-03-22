import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/recurring_transactions_repository.dart';
import '../../data/subcategories_repository.dart';
import '../../domain/parsed_voice_transaction.dart';
import '../../domain/recurring_transaction_model.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/subcategories_provider.dart';
import '../providers/transactions_provider.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/category_selector_row.dart';
import '../widgets/create_subcategory_dialog.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction, this.voiceData});

  final TransactionModel? transaction;
  final ParsedVoiceTransaction? voiceData;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

// ── Recurrence info banner ────────────────────────────────────────────────────

class _RecurrenceInfoBanner extends StatelessWidget {
  const _RecurrenceInfoBanner({required this.date, required this.type});
  final DateTime date;
  final RecurrenceType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final next = nextRecurrenceDate(date, type);
    final dayStr =
        '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
    final freq = switch (type) {
      RecurrenceType.weekly => l10n.frequencyWeek,
      RecurrenceType.monthly => l10n.frequencyMonth,
      RecurrenceType.annual => l10n.frequencyYear,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.dustyTealLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('🔁', style: TextStyle(fontSize: 16)),
          const Gap(10),
          Expanded(
            child: Text(
              l10n.nextRepetition(dayStr, freq),
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.dustyTeal,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _type;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  String? _selectedCategory;
  String? _selectedSubcategory;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _isRecurring = false;
  RecurrenceType? _recurrenceType;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    final v = widget.voiceData;
    _type = t?.type ?? v?.type ?? TransactionType.expense;
    _amountController = TextEditingController(
      text: t != null
          ? t.amount.toStringAsFixed(2)
          : v != null
              ? v.amount.toStringAsFixed(2)
              : '',
    );
    _descriptionController = TextEditingController(text: t?.description ?? v?.description ?? '');
    _selectedCategory = t?.category ?? v?.category;
    _selectedSubcategory = t?.subcategory ?? v?.subcategory;
    _selectedDate = t?.date ?? v?.date ?? DateTime.now();
    // If voice AI detected recurring, pre-fill it
    if (v?.isRecurring == true) {
      _isRecurring = true;
      _recurrenceType = switch (v?.recurrenceType) {
        'weekly' => RecurrenceType.weekly,
        'annual' => RecurrenceType.annual,
        _ => RecurrenceType.monthly,
      };
    }
    // If voice/image AI provided a subcategory, ensure it exists in the DB.
    // We always upsert: if it's new (isNewSubcategory: true) or if the AI
    // incorrectly flagged an existing match that isn't actually in the DB.
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
        } catch (_) {
          // Subcategory creation failed — not critical, user can add manually
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
    _amountController.dispose();
    _descriptionController.dispose();
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
      // Run smart details flow after category selection
      await _runDetailsFlow();
    }
  }

  /// Sequential bottom sheets: subcategory → description
  Future<void> _runDetailsFlow() async {
    if (_selectedCategory == null || !mounted) return;
    final accentColor =
        _type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight =
        _type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

    // Step 1: Subcategory (always show — user can create new ones)
    if (mounted) {
      final sub = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _SubcategoryPickerSheet(
          selected: _selectedSubcategory,
          category: _selectedCategory!,
          type: _type,
          accentColor: accentColor,
          accentLight: accentLight,
        ),
      );
      if (mounted && sub != null) {
        setState(() => _selectedSubcategory = sub);
      }
    }

    // Step 2: Description
    if (!mounted) return;
    final desc = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DescriptionInputSheet(
        initialValue: _descriptionController.text,
      ),
    );
    if (mounted && desc != null) {
      setState(() => _descriptionController.text = desc);
    }
  }

  Future<void> _pickDate() async {
    final cs = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Clamp initialDate so it's never after lastDate (voice AI can return future dates)
    final initialDate = _selectedDate.isAfter(today) ? today : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: today,
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final currentCurrency = ref.read(currencyProvider).valueOrNull ?? 'EUR';
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      context.showSnackbar(l10n.invalidAmount, isError: true);
      return;
    }
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
            // Actualiza la entrada existente en recurring_transactions
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
            // La transacción no era recurrente → crear nueva entrada
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
          // Se quitó la recurrencia → eliminar el registro de recurring_transactions
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
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
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
    final cs = context.colors;
    final customCats = ref.watch(customCategoriesSyncProvider);

    final accentColor = _type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight = _type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editTransaction : l10n.newTransaction),
        actions: [
          if (_isEditing)
            GestureDetector(
              onTap: _delete,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.mutedTerraLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text('🗑️', style: TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Expense / Income toggle ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: TransactionType.values.map((type) {
                  final isSelected = _type == type;
                  final isIncome = type.isIncome;
                  final color = isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
                  final lightColor = isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;
                  final emoji = isIncome ? '💰' : '💳';

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _type = type;
                          _selectedCategory = null;
                          _selectedSubcategory = null;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? cs.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected ? AppColors.softShadowSm : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected ? lightColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(emoji, style: const TextStyle(fontSize: 14)),
                              ),
                            ),
                            const Gap(8),
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
                  );
                }).toList(),
              ),
            ),
            const Gap(16),

            // ── Amount (compact) ────────────────────────────────────────
            NeoCard(
              accentColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                      ],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: -1,
                      ),
                      decoration: InputDecoration(
                        prefixText:
                            '${currencySymbol(ref.watch(currencyProvider).valueOrNull ?? 'EUR')} ',
                        prefixStyle: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: accentColor.withValues(alpha: 0.35),
                        ),
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface.withValues(alpha: 0.08),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1),
                    ),
                    child: Text(
                      ref.watch(currencyProvider).valueOrNull ?? 'EUR',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),

            // ── Category selector ─────────────────────────────────────────
            CategorySelectorRow(
              selectedCategory: _selectedCategory,
              type: _type,
              accentColor: accentColor,
              accentLight: accentLight,
              customCategories: customCats[_type] ?? [],
              onTap: _openCategoryPicker,
            ),
            const Gap(16),

            // ── Date ──────────────────────────────────────────────────────
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.softShadowSm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.warmAmberLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('📅', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const Gap(12),
                    Text(
                      _selectedDate.formattedDate,
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSubtle,
                    ),
                  ],
                ),
              ),
            ),
            // ── Detail chips (subcategory + description) ─────────────────
            if (_selectedSubcategory != null ||
                _descriptionController.text.trim().isNotEmpty) ...[
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedSubcategory != null)
                    _DetailChip(
                      emoji: '🏷',
                      label: _selectedSubcategory!,
                      accentColor: accentColor,
                      onTap: () async {
                        final sub = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          builder: (_) => _SubcategoryPickerSheet(
                            selected: _selectedSubcategory,
                            category: _selectedCategory!,
                            type: _type,
                            accentColor: accentColor,
                            accentLight: accentLight,
                          ),
                        );
                        if (mounted && sub != null) {
                          setState(() => _selectedSubcategory = sub);
                        }
                      },
                      onClear: () =>
                          setState(() => _selectedSubcategory = null),
                    ),
                  if (_descriptionController.text.trim().isNotEmpty)
                    _DetailChip(
                      emoji: '📝',
                      label: _descriptionController.text.trim(),
                      accentColor: accentColor,
                      onTap: () async {
                        final desc = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          builder: (_) => _DescriptionInputSheet(
                            initialValue: _descriptionController.text,
                          ),
                        );
                        if (mounted && desc != null) {
                          setState(
                              () => _descriptionController.text = desc);
                        }
                      },
                      onClear: () =>
                          setState(() => _descriptionController.clear()),
                    ),
                ],
              ),
            ],
            const Gap(16),

            // ── Recurring ─────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surface,
                border:
                    Border.all(color: AppColors.borderLight, width: 1.5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.softShadowSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.dustyTealLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('🔁', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      l10n.recurringTransaction,
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isRecurring,
                    onChanged: (v) => setState(() {
                      _isRecurring = v;
                      _recurrenceType = v ? RecurrenceType.monthly : null;
                    }),
                  ),
                ],
              ),
            ),
            if (_isRecurring) ...[
              const Gap(12),
              SegmentedButton<RecurrenceType>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: RecurrenceType.weekly,
                    label: Text(l10n.weekly),
                    icon: const Icon(Icons.calendar_view_week_outlined,
                        size: 16),
                  ),
                  ButtonSegment(
                    value: RecurrenceType.monthly,
                    label: Text(l10n.monthly),
                    icon: const Icon(Icons.calendar_month_outlined,
                        size: 16),
                  ),
                  ButtonSegment(
                    value: RecurrenceType.annual,
                    label: Text(l10n.yearly),
                    icon: const Icon(Icons.event_repeat_outlined,
                        size: 16),
                  ),
                ],
                selected: {_recurrenceType ?? RecurrenceType.monthly},
                onSelectionChanged: (s) =>
                    setState(() => _recurrenceType = s.first),
              ),
              if (_recurrenceType != null) ...[
                const Gap(12),
                _RecurrenceInfoBanner(
                  date: _selectedDate,
                  type: _recurrenceType!,
                ),
              ],
            ],
            const Gap(16),

            // ── Save button ───────────────────────────────────────────────
            NeoBrutalButton(
              label: _isEditing
                  ? l10n.saveChanges
                  : _type.isIncome
                      ? l10n.saveIncome
                      : l10n.saveExpense,
              backgroundColor: accentColor,
              foregroundColor: AppColors.pureWhite,
              isLoading: _isSaving,
              disabled: _isSaving,
              onTap: _save,
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }

}





// ── Detail chip (summary) ─────────────────────────────────────────────────────

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.emoji,
    required this.label,
    required this.accentColor,
    required this.onTap,
    required this.onClear,
  });

  final String emoji;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const Gap(6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
            const Gap(4),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded,
                  size: 14, color: accentColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
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
    final subcategories = asyncSubs.valueOrNull ?? [];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    l10n.tutorialSkip,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...subcategories.map((name) {
                  final isSelected = selected == name;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.only(
                        left: 14, top: 4, bottom: 4, right: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? accentLight : cs.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSelected
                            ? accentColor
                            : AppColors.borderLight,
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
                        const Gap(6),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            _confirmDeleteSubcategory(
                              context, ref, name,
                            );
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
                // New subcategory button
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
                      borderRadius: BorderRadius.circular(100),
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
                        const Gap(4),
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
          const Gap(24),
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

// ── Description input sheet ───────────────────────────────────────────────────

class _DescriptionInputSheet extends StatefulWidget {
  const _DescriptionInputSheet({required this.initialValue});
  final String initialValue;

  @override
  State<_DescriptionInputSheet> createState() => _DescriptionInputSheetState();
}

class _DescriptionInputSheetState extends State<_DescriptionInputSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  l10n.descriptionOptional.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    l10n.tutorialSkip,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dustyTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontFamily: 'Sora',
                color: cs.onSurface,
                fontSize: 15,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: l10n.descriptionHint,
              ),
              onFieldSubmitted: (_) =>
                  Navigator.pop(context, _controller.text.trim()),
            ),
          ),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, _controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dustyTeal,
                  foregroundColor: AppColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  l10n.save,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
