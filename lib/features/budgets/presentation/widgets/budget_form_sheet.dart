import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_manager/core/config/router.dart';
import 'package:expense_manager/core/errors/failure_localizations.dart';
import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Abre el formulario de presupuesto (crear si [existing] es null, editar si
/// no). Gestiona el guardado y los errores, incluido el CTA a PRO cuando un
/// usuario FREE alcanza su límite ([FreeLimitFailure]).
Future<void> showBudgetFormSheet(
  BuildContext context,
  WidgetRef ref, {
  BudgetModel? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _BudgetFormSheet(existing: existing),
  );
}

/// Diálogo con CTA a /pro cuando el plan FREE alcanza su límite de
/// presupuestos. Expuesto para usarlo también como preflight desde la pantalla.
Future<void> showBudgetUpgradeDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.budgets),
      content: Text(l10n.errorFreePlanLimit),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            ctx.push(AppRoutes.pro);
          },
          child: Text(l10n.budgetUpgradeCta),
        ),
      ],
    ),
  );
}

class _BudgetFormSheet extends ConsumerStatefulWidget {
  const _BudgetFormSheet({this.existing});

  final BudgetModel? existing;

  @override
  ConsumerState<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<_BudgetFormSheet> {
  late final TextEditingController _amountController;
  String? _category;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _category = widget.existing?.category;
    _amountController = TextEditingController(
      text: widget.existing == null
          ? ''
          : _trimTrailingZeros(widget.existing!.amount),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  static String _trimTrailingZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Categorías de gasto (builtin + custom) sin presupuesto asignado todavía,
  /// conservando la del presupuesto en edición.
  List<String> _availableCategories() {
    final custom = ref
            .watch(customCategoriesProvider)
            .value?[TransactionType.expense] ??
        const [];
    final all = [
      ...TransactionCategories.expense.map((c) => c.name),
      ...custom.map((c) => c.name),
    ];
    final used = (ref.watch(budgetsProvider).value ?? const [])
        .map((b) => b.category)
        .toSet()
      ..remove(widget.existing?.category);
    return [
      for (final name in all)
        if (!used.contains(name)) name,
    ];
  }

  double? _parseAmount() {
    final raw = _amountController.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final amount = _parseAmount();
    final category = _category;
    if (amount == null || category == null) return;

    setState(() => _saving = true);
    try {
      final notifier = ref.read(budgetsProvider.notifier);
      if (_isEditing) {
        await notifier.updateBudget(
          widget.existing!.copyWith(category: category, amount: amount),
        );
      } else {
        await notifier.create(category: category, amount: amount);
      }
      if (mounted) Navigator.pop(context);
    } on FreeLimitFailure {
      if (!mounted) return;
      Navigator.pop(context);
      await showBudgetUpgradeDialog(context);
    } on AppFailure catch (f) {
      if (!mounted) return;
      context.showSnackbar(f.localizedMessage(l10n), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final categories = _availableCategories();
    final cSymbol = currencySymbol(ref.watch(currencyProvider).value ?? 'EUR');
    final canSave =
        !_saving && _category != null && _parseAmount() != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          AppSpacing.lg,
          20,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? l10n.budgetEdit : l10n.budgetNew,
              style: context.textTheme.titleMedium,
            ),
            const Gap(16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.category,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final name in categories)
                  DropdownMenuItem(
                    value: name,
                    child: Text(
                      '${TransactionCategories.emojiFor(name)}  '
                      '${TransactionCategories.localizedName(name, l10n)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _category = value),
            ),
            const Gap(12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: l10n.budgetMonthlyLimit,
                prefixText: '$cSymbol ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const Gap(20),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
