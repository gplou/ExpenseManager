import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/utils/extensions.dart';
import '../../domain/transaction_categories.dart';
import '../../domain/transaction_model.dart';
import '../providers/transactions_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  TransactionType _type = TransactionType.expense;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

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

    setState(() => _isSaving = true);
    try {
      final transaction = TransactionModel(
        id: '',
        userId: '',
        amount: amount,
        type: _type,
        category: _selectedCategory!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        date: _selectedDate,
        createdAt: DateTime.now(),
      );
      await ref.read(transactionsNotifierProvider.notifier).create(transaction);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        context.showSnackbar('Error al guardar', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva transacción'),
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
            const Gap(40),

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
                  : Text('Guardar ${_type.label.toLowerCase()}'),
            ),
          ],
        ),
      ),
    );
  }
}
