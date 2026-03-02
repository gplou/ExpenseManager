import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/utils/extensions.dart';
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

  /// Si se pasa una transacción existente, la pantalla opera en modo edición.
  final TransactionModel? transaction;

  /// Datos pre-rellenados desde el reconocimiento de voz (solo en modo creación).
  final ParsedVoiceTransaction? voiceData;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

// ── Info banner ───────────────────────────────────────────────────────────────

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
    final freq = type == RecurrenceType.weekly
        ? l10n.frequencyWeek
        : l10n.frequencyMonth;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: context.colors.primary.withValues(alpha: 0.8),
          ),
          const Gap(8),
          Expanded(
            child: Text(
              l10n.nextRepetition(dayStr, freq),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.primary.withValues(alpha: 0.9),
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

  Future<void> _confirmDeleteCategory(String name, {required bool isCustom}) async {
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
            child: Text(l10n.delete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (isCustom) {
      await ref.read(customCategoriesProvider.notifier).remove(_type, name);
    } else {
      await ref.read(hiddenBuiltInCategoriesProvider.notifier).hide(_type, name);
    }
    if (_selectedCategory == name) setState(() => _selectedCategory = null);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
        await ref
            .read(transactionsNotifierProvider.notifier)
            .update(updated);
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
              style: const TextStyle(color: Colors.red),
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
    final customCats = ref.watch(customCategoriesProvider);
    final hiddenBuiltIns = ref.watch(hiddenBuiltInCategoriesProvider);
    final builtInCategories = TransactionCategories.forType(_type)
        .where((c) => !(hiddenBuiltIns[_type]?.contains(c.name) ?? false))
        .toList();
    final allCategories = [
      ...builtInCategories,
      ...(customCats[_type] ?? []),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEditing ? l10n.editTransaction : l10n.newTransaction),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: l10n.delete,
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Toggle Gasto / Ingreso ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: TransactionType.values.map((type) {
                  final isSelected = _type == type;
                  final color = type.isIncome ? Colors.green : Colors.red;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = type;
                        _selectedCategory = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? color : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          type.l10nLabel(l10n),
                          textAlign: TextAlign.center,
                          style: context.textTheme.labelLarge?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : context.colors.onSurface
                                    .withValues(alpha: 0.6),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Gap(28),

            // ── Importe ──────────────────────────────────────────────────
            Text(l10n.amount, style: context.textTheme.labelMedium),
            const Gap(8),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefixText: '€ ',
                prefixStyle: context.textTheme.headlineMedium?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.5),
                ),
                hintText: l10n.amountHint,
              ),
            ),
            const Gap(28),

            // ── Categoría ────────────────────────────────────────────────
            Text(l10n.category, style: context.textTheme.labelMedium),
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...allCategories.map((cat) {
                  final isSelected = _selectedCategory == cat.name;
                  final isCustom = !TransactionCategories.forType(_type)
                      .any((c) => c.name == cat.name);
                  return InputChip(
                    avatar: Icon(cat.icon, size: 16),
                    label: Text(
                      TransactionCategories.localizedName(cat.name, l10n),
                    ),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat.name),
                    onDeleted: () =>
                        _confirmDeleteCategory(cat.name, isCustom: isCustom),
                    deleteIcon: const Icon(Icons.close, size: 14),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(l10n.newCategory),
                  onPressed: _openCreateCategoryDialog,
                ),
              ],
            ),
            const Gap(28),

            // ── Descripción ──────────────────────────────────────────────
            Text(l10n.descriptionOptional,
                style: context.textTheme.labelMedium),
            const Gap(8),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l10n.descriptionHint,
              ),
            ),
            const Gap(28),

            // ── Fecha ────────────────────────────────────────────────────
            Text(l10n.date, style: context.textTheme.labelMedium),
            const Gap(8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: context.colors.outline.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: context.colors.onSurface
                          .withValues(alpha: 0.6),
                    ),
                    const Gap(12),
                    Text(
                      _selectedDate.formattedDate,
                      style: context.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      color: context.colors.onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(28),

            // ── Recurrente (solo al crear) ────────────────────────────────
            if (!_isEditing) ...[
              Row(
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 18,
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      l10n.recurringTransaction,
                      style: context.textTheme.labelMedium,
                    ),
                  ),
                  Switch(
                    value: _isRecurring,
                    onChanged: (v) => setState(() {
                      _isRecurring = v;
                      _recurrenceType =
                          v ? RecurrenceType.monthly : null;
                    }),
                  ),
                ],
              ),
              if (_isRecurring) ...[
                const Gap(8),
                SegmentedButton<RecurrenceType>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: RecurrenceType.weekly,
                      label: Text(l10n.weekly),
                      icon: const Icon(
                          Icons.calendar_view_week_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: RecurrenceType.monthly,
                      label: Text(l10n.monthly),
                      icon: const Icon(
                          Icons.calendar_month_outlined, size: 16),
                    ),
                  ],
                  selected: {_recurrenceType ?? RecurrenceType.monthly},
                  onSelectionChanged: (s) =>
                      setState(() => _recurrenceType = s.first),
                ),
                if (_recurrenceType != null) ...[
                  const Gap(10),
                  _RecurrenceInfoBanner(
                    date: _selectedDate,
                    type: _recurrenceType!,
                  ),
                ],
              ],
              const Gap(28),
            ],

            // ── Botón guardar ────────────────────────────────────────────
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _type.isIncome ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditing
                          ? l10n.saveChanges
                          : _type.isIncome
                              ? l10n.saveIncome
                              : l10n.saveExpense,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
