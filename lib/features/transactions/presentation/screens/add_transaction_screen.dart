import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/recurring_transactions_repository.dart';
import '../../domain/parsed_voice_transaction.dart';
import '../../domain/recurring_transaction_model.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/hidden_builtin_categories_provider.dart';
import '../providers/transactions_provider.dart';
import '../widgets/create_category_dialog.dart';

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
    final freq =
        type == RecurrenceType.weekly ? l10n.frequencyWeek : l10n.frequencyMonth;

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
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _selectedCategory = t?.category;
    _selectedDate = t?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _openCreateCategoryDialog() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => CreateCategoryDialog(type: _type),
    );
    if (newName != null) setState(() => _selectedCategory = newName);
  }

  Future<void> _confirmDeleteCategory(
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
    if (confirmed != true || !mounted) return;
    if (isCustom) {
      await ref.read(customCategoriesProvider.notifier).remove(_type, name);
    } else {
      await ref
          .read(hiddenBuiltInCategoriesProvider.notifier)
          .hide(_type, name);
    }
    if (_selectedCategory == name) setState(() => _selectedCategory = null);
  }

  Future<void> _pickDate() async {
    final cs = context.colors;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
          description: desc,
          date: _selectedDate,
        );
        await ref.read(transactionsNotifierProvider.notifier).update(updated);
      } else {
        final transaction = TransactionModel(
          id: '',
          userId: '',
          amount: amount,
          type: _type,
          category: _selectedCategory!,
          description: desc,
          date: _selectedDate,
          createdAt: DateTime.now(),
        );
        await ref
            .read(transactionsNotifierProvider.notifier)
            .create(transaction);

        if (_isRecurring && _recurrenceType != null) {
          final nextDate = nextRecurrenceDate(_selectedDate, _recurrenceType!);
          await ref
              .read(recurringTransactionsRepositoryProvider)
              .createRecurring(
                amount: amount,
                type: _type,
                category: _selectedCategory!,
                description: desc,
                recurrenceType: _recurrenceType!,
                nextOccurrence: nextDate,
              );
        }
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteTransactionConfirm),
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
        .delete(widget.transaction!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final customCats = ref.watch(customCategoriesProvider);
    final hiddenBuiltIns = ref.watch(hiddenBuiltInCategoriesProvider);
    final builtInCategories = TransactionCategories.forType(_type)
        .where((c) => !(hiddenBuiltIns[_type]?.contains(c.name) ?? false))
        .toList();
    final allCategories = [
      ...builtInCategories,
      ...(customCats[_type] ?? []),
    ];

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
            // ── Toggle Gasto / Ingreso ────────────────────────────────────
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
            const Gap(28),

            // ── Importe ───────────────────────────────────────────────────
            NeoCard(
              accentColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    l10n.amount.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.textSubtle,
                    ),
                  ),
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                    ],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: -1,
                    ),
                    decoration: InputDecoration(
                      prefixText: '€ ',
                      prefixStyle: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: accentColor.withValues(alpha: 0.35),
                      ),
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface.withValues(alpha: 0.08),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(28),

            // ── Categoría ─────────────────────────────────────────────────
            _SectionLabel(label: l10n.category),
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...allCategories.map((cat) {
                  final isSelected = _selectedCategory == cat.name;
                  final isCustom = !TransactionCategories.forType(_type)
                      .any((c) => c.name == cat.name);
                  final catEmoji = _emojiForCategory(cat.name, _type.isIncome);
                  return _CategoryChip(
                    label: TransactionCategories.localizedName(cat.name, l10n),
                    emoji: catEmoji,
                    iconOverride: isCustom ? cat.icon : null,
                    isSelected: isSelected,
                    accentColor: accentColor,
                    accentLight: accentLight,
                    onTap: () => setState(() => _selectedCategory = cat.name),
                    onDelete: () =>
                        _confirmDeleteCategory(cat.name, isCustom: isCustom),
                  );
                }),
                _AddCategoryChip(
                  label: l10n.newCategory,
                  onTap: _openCreateCategoryDialog,
                ),
              ],
            ),
            const Gap(28),

            // ── Descripción ───────────────────────────────────────────────
            _SectionLabel(label: l10n.descriptionOptional),
            const Gap(8),
            TextFormField(
              controller: _descriptionController,
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
            ),
            const Gap(28),

            // ── Fecha ─────────────────────────────────────────────────────
            _SectionLabel(label: l10n.date),
            const Gap(8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
            const Gap(28),

            // ── Recurrente (solo al crear) ─────────────────────────────────
            if (!_isEditing) ...[
              Container(
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
                      icon: const Icon(Icons.calendar_view_week_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: RecurrenceType.monthly,
                      label: Text(l10n.monthly),
                      icon: const Icon(Icons.calendar_month_outlined, size: 16),
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
              const Gap(28),
            ],

            // ── Botón guardar ─────────────────────────────────────────────
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

  String _emojiForCategory(String category, bool isIncome) => switch (category) {
    'Salario'    => '💼',
    'Freelance'  => '💻',
    'Inversión'  => '📈',
    'Regalo'     => '🎁',
    'Comida'     => '🍕',
    'Transporte' => '🚗',
    'Vivienda'   => '🏠',
    'Ocio'       => '🎮',
    'Salud'      => '💊',
    'Educación'  => '📚',
    'Ropa'       => '👕',
    'Tecnología' => '⚡',
    _            => isIncome ? '💰' : '💸',
  };
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Sora',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: AppColors.textMuted,
      ),
    );
  }
}

// ── Category chips ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.emoji,
    this.iconOverride,
    required this.isSelected,
    required this.accentColor,
    required this.accentLight,
    required this.onTap,
    required this.onDelete,
  });

  final String label;
  final String emoji;
  final IconData? iconOverride;
  final bool isSelected;
  final Color accentColor;
  final Color accentLight;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final deleteColor = isSelected
        ? accentColor.withValues(alpha: 0.55)
        : AppColors.textSubtle;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? accentLight : cs.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isSelected ? accentColor : AppColors.borderLight,
          width: 1.5,
        ),
        boxShadow: isSelected ? null : AppColors.softShadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zona de selección
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconOverride != null)
                    Icon(iconOverride, size: 14,
                        color: isSelected ? accentColor : AppColors.textMuted)
                  else
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                  const Gap(6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? accentColor : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Botón eliminar
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onDelete();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 10, 8),
              child: Icon(Icons.close_rounded, size: 13, color: deleteColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCategoryChip extends StatelessWidget {
  const _AddCategoryChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const Icon(Icons.add_rounded, size: 14, color: AppColors.dustyTeal),
            const Gap(4),
            Text(
              label,
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
    );
  }
}
