import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/errors/failure_localizations.dart';
import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/ad_banner_footer.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/budgets/presentation/widgets/budget_form_sheet.dart';
import 'package:expense_manager/features/budgets/presentation/widgets/budget_progress_tile.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  Future<void> _addBudget(BuildContext context, WidgetRef ref) async {
    // Preflight del límite FREE: evita abrir el form para fallar al guardar.
    // El notifier mantiene la misma regla como defensa. Esperamos el future
    // (no .value) por si el provider aún está cargando.
    final isPro = ref.read(isProProvider);
    final count = (await ref.read(budgetsProvider.future)).length;
    if (!context.mounted) return;
    if (!isPro && count >= kFreeBudgetLimit) {
      await showBudgetUpgradeDialog(context);
      return;
    }
    await showBudgetFormSheet(context, ref);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String budgetId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.budgetDeleteConfirm),
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
    try {
      await ref.read(budgetsProvider.notifier).deleteBudget(budgetId);
    } on AppFailure catch (f) {
      if (context.mounted) {
        context.showSnackbar(f.localizedMessage(l10n), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final progressAsync = ref.watch(budgetProgressProvider);
    final cSymbol = currencySymbol(ref.watch(currencyProvider).value ?? 'EUR');
    final numFmtStyle =
        ref.watch(numberFormatProvider).value ?? NumberFormatStyle.dotDecimal;

    return Scaffold(
      bottomNavigationBar:
          ref.watch(isProProvider) ? null : const AdBannerFooter(),
      appBar: AppBar(title: Text(l10n.budgets)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.budgetNew,
        onPressed: () => _addBudget(context, ref),
        child: Icon(PhosphorIcons.plus()),
      ),
      body: progressAsync.when(
        skipLoadingOnReload: true,
        loading: () => Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            e is AppFailure ? e.localizedMessage(l10n) : l10n.errorLoading,
            textAlign: TextAlign.center,
          ),
        ),
        data: (progresses) {
          if (progresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: context.appColors.raised,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.piggyBank(),
                        size: 26,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const Gap(16),
                    Text(
                      l10n.budgetNoBudgets,
                      textAlign: TextAlign.center,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      l10n.budgetNoBudgetsSubtitle,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).padding.bottom + 88,
            ),
            itemCount: progresses.length,
            itemBuilder: (context, index) {
              final progress = progresses[index];
              return BudgetProgressTile(
                progress: progress,
                cSymbol: cSymbol,
                numFmtStyle: numFmtStyle,
                onTap: () => showBudgetFormSheet(
                  context,
                  ref,
                  existing: progress.budget,
                ),
                trailing: IconButton(
                  tooltip: l10n.delete,
                  icon: Icon(
                    PhosphorIcons.trash(),
                    size: 20,
                    color: AppColors.mutedTerra,
                  ),
                  onPressed: () =>
                      _confirmDelete(context, ref, progress.budget.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
