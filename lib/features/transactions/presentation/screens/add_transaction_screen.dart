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
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/subcategories_provider.dart';
import '../providers/transactions_provider.dart';
import '../widgets/category_picker_sheet.dart';
import '../../../subscription/subscription_provider.dart';
import '../../../../core/widgets/ad_banner_footer.dart';
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
    }
  }

  String _resolveCategoryEmoji(
      String category, bool isIncome, List<TransactionCategory> customCats) {
    // Check custom categories first (emoji stored in emojiOverride)
    final custom = customCats.where((c) => c.name == category).firstOrNull;
    if (custom != null && custom.emojiOverride != null) {
      return custom.emojiOverride!;
    }
    return TransactionCategories.emojiFor(category, isIncome: isIncome);
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final currentCurrency = ref.read(currencyProvider).value ?? 'EUR';
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
      bottomNavigationBar: ref.watch(isProProvider) ? null : const AdBannerFooter(),
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
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
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
                        _DecimalLimitFormatter(3),
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
                            '${currencySymbol(ref.watch(currencyProvider).value ?? 'EUR')} ',
                        prefixStyle: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: accentColor.withValues(alpha: 0.35),
                        ),
                        hintText: l10n.amountHint,
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
                      ref.watch(currencyProvider).value ?? 'EUR',
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

            // ── Category + Subcategory row ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _CompactCard(
                    emoji: _selectedCategory != null
                        ? _resolveCategoryEmoji(
                            _selectedCategory!, _type.isIncome, customCats[_type] ?? [])
                        : null,
                    label: _selectedCategory != null
                        ? TransactionCategories.localizedName(
                            _selectedCategory!, l10n)
                        : l10n.category,
                    hasValue: _selectedCategory != null,
                    accentColor: accentColor,
                    accentLight: accentLight,
                    onTap: _openCategoryPicker,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: _CompactCard(
                    emoji: _selectedSubcategory != null ? '🏷' : null,
                    label: _selectedSubcategory ?? l10n.subcategory,
                    hasValue: _selectedSubcategory != null,
                    disabled: _selectedCategory == null,
                    accentColor: accentColor,
                    accentLight: accentLight,
                    onTap: _selectedCategory != null
                        ? () async {
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
                          }
                        : null,
                  ),
                ),
              ],
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
            const Gap(10),

            // ── Description field ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border.all(color: AppColors.borderLight, width: 1.5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.softShadowSm,
              ),
              child: TextFormField(
                controller: _descriptionController,
                maxLines: 1,
                maxLength: 50,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  icon: const Text('📝', style: TextStyle(fontSize: 18)),
                  hintText: l10n.descriptionOptional,
                  hintStyle: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
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

// ── Compact card (category / subcategory) ─────────────────────────────────────

class _CompactCard extends StatelessWidget {
  const _CompactCard({
    required this.label,
    required this.hasValue,
    required this.accentColor,
    required this.accentLight,
    required this.onTap,
    this.emoji,
    this.disabled = false,
  });

  final String? emoji;
  final String label;
  final bool hasValue;
  final Color accentColor;
  final Color accentLight;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: disabled
              ? cs.onSurface.withValues(alpha: 0.04)
              : hasValue
                  ? accentLight
                  : cs.surface,
          border: Border.all(
            color: disabled
                ? cs.onSurface.withValues(alpha: 0.08)
                : hasValue
                    ? accentColor
                    : AppColors.borderLight,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: (hasValue || disabled) ? null : AppColors.softShadowSm,
        ),
        child: Row(
          children: [
            if (emoji != null) ...[
              Opacity(
                opacity: disabled ? 0.3 : 1.0,
                child: Text(emoji!, style: const TextStyle(fontSize: 16)),
              ),
              const Gap(8),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? cs.onSurface.withValues(alpha: 0.2)
                      : hasValue
                          ? accentColor
                          : AppColors.textMuted,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: disabled
                  ? cs.onSurface.withValues(alpha: 0.12)
                  : hasValue
                      ? accentColor
                      : AppColors.textSubtle,
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
    final subcategories = asyncSubs.value ?? [];

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

// ── Decimal limit formatter ───────────────────────────────────────────────────

class _DecimalLimitFormatter extends TextInputFormatter {
  _DecimalLimitFormatter(this.maxDecimals);
  final int maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final dotIndex = text.lastIndexOf('.');
    final commaIndex = text.lastIndexOf(',');
    final sepIndex = dotIndex > commaIndex ? dotIndex : commaIndex;
    if (sepIndex < 0) return newValue;
    final decimals = text.length - sepIndex - 1;
    if (decimals > maxDecimals) return oldValue;
    return newValue;
  }
}
