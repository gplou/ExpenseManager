import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/utils/extensions.dart';
import '../../data/recurring_transactions_repository.dart';
import '../../domain/recurring_transaction_model.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/transactions_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction});

  /// Si se pasa una transacción existente, la pantalla opera en modo edición.
  final TransactionModel? transaction;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

// ── Info banner ────────────────────────────────────────────────────────────────

class _RecurrenceInfoBanner extends StatelessWidget {
  const _RecurrenceInfoBanner({required this.date, required this.type});
  final DateTime date;
  final RecurrenceType type;

  @override
  Widget build(BuildContext context) {
    final next = nextRecurrenceDate(date, type);
    final dayStr =
        '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
    final freq = type == RecurrenceType.weekly ? 'semana' : 'mes';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15,
              color: context.colors.primary.withValues(alpha: 0.8)),
          const Gap(8),
          Expanded(
            child: Text(
              'La próxima repetición será el $dayStr y cada $freq a partir de entonces.',
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

// ── Screen ─────────────────────────────────────────────────────────────────────

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
    _type = t?.type ?? TransactionType.expense;
    _amountController = TextEditingController(
      text: t != null ? t.amount.toStringAsFixed(2) : '',
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

  List<TransactionCategory> get _categories =>
      TransactionCategories.forType(_type);

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
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      context.showSnackbar('Ingresa un importe válido', isError: true);
      return;
    }
    if (_selectedCategory == null) {
      context.showSnackbar('Selecciona una categoría', isError: true);
      return;
    }
    if (_isRecurring && _recurrenceType == null) {
      context.showSnackbar('Selecciona la frecuencia de repetición',
          isError: true);
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

        // Guardar la plantilla recurrente si procede
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
          _isEditing ? 'Error al actualizar' : 'Error al guardar',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar esta transacción?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar transacción' : 'Nueva transacción'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Toggle Gasto / Ingreso ──────────────────────────────────────
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
                          type.label,
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

            // ── Importe ────────────────────────────────────────────────────
            Text('Importe', style: context.textTheme.labelMedium),
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
                hintText: '0,00',
              ),
            ),
            const Gap(28),

            // ── Categoría ──────────────────────────────────────────────────
            Text('Categoría', style: context.textTheme.labelMedium),
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.name;
                return ChoiceChip(
                  avatar: Icon(cat.icon, size: 16),
                  label: Text(cat.name),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat.name),
                );
              }).toList(),
            ),
            const Gap(28),

            // ── Descripción ────────────────────────────────────────────────
            Text('Descripción (opcional)', style: context.textTheme.labelMedium),
            const Gap(8),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Añade una nota...',
              ),
            ),
            const Gap(28),

            // ── Fecha ──────────────────────────────────────────────────────
            Text('Fecha', style: context.textTheme.labelMedium),
            const Gap(8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        context.colors.outline.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 18,
                        color: context.colors.onSurface
                            .withValues(alpha: 0.6)),
                    const Gap(12),
                    Text(
                      _selectedDate.formattedDate,
                      style: context.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        color: context.colors.onSurface
                            .withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
            const Gap(28),

            // ── Recurrente (solo al crear) ──────────────────────────────────
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
                      'Transacción recurrente',
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
                  segments: const [
                    ButtonSegment(
                      value: RecurrenceType.weekly,
                      label: Text('Semanal'),
                      icon: Icon(Icons.calendar_view_week_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: RecurrenceType.monthly,
                      label: Text('Mensual'),
                      icon: Icon(Icons.calendar_month_outlined, size: 16),
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

            // ── Botón guardar ──────────────────────────────────────────────
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
                          ? 'Guardar cambios'
                          : 'Guardar ${_type.label.toLowerCase()}',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
