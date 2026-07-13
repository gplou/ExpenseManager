import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_manager/core/config/router.dart';
import 'package:expense_manager/core/constants/test_keys.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/budgets/presentation/widgets/budget_progress_tile.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Sección de presupuestos del dashboard (entre Summary y Recent).
///
/// Con presupuestos: barras de progreso del mes + enlace a gestión.
/// Sin presupuestos: CTA compacto para crear el primero.
/// También dispara las alertas de 80%/100% (snackbar, una vez por presupuesto
/// y mes — ver [BudgetAlerts]).
class BudgetsSection extends ConsumerWidget {
  const BudgetsSection({
    super.key,
    required this.cSymbol,
    required this.numFmtStyle,
  });

  final String cSymbol;
  final NumberFormatStyle numFmtStyle;

  void _listenForAlerts(BuildContext context, WidgetRef ref) {
    ref.listen(budgetProgressProvider, (previous, next) async {
      final progresses = next.value;
      if (progresses == null || progresses.isEmpty) return;
      final crossings = await BudgetAlerts.consumeUnnotified(progresses);
      if (crossings.isEmpty || !context.mounted) return;
      // Solo el primero para no encolar varios snackbars en el mismo frame.
      final (progress, threshold) = crossings.first;
      final l10n = AppLocalizations.of(context);
      final category = TransactionCategories.localizedName(
        progress.budget.category,
        l10n,
      );
      context.showSnackbar(
        threshold >= 100
            ? l10n.budgetLimitReached(category)
            : l10n.budgetNearLimit(category),
        isError: threshold >= 100,
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final progressAsync = ref.watch(budgetProgressProvider);

    _listenForAlerts(context, ref);

    return progressAsync.when(
      // Sin datos aún (primer load): no ocupar espacio en el dashboard.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      skipLoadingOnReload: true,
      data: (progresses) {
        if (progresses.isEmpty) {
          return _EmptyCta(l10n: l10n);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.budgets.toUpperCase(),
                      style: context.textTheme.labelMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.budgetsManage,
                    child: InkWell(
                      key: TestKeys.budgetsSectionLink,
                      onTap: () => context.push(AppRoutes.budgets),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.budgetsManage,
                              style: context.textTheme.labelMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Gap(2),
                            Icon(Icons.chevron_right_rounded,
                                size: 16, color: cs.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(4),
            ...progresses.map(
              (p) => BudgetProgressTile(
                progress: p,
                cSymbol: cSymbol,
                numFmtStyle: numFmtStyle,
                onTap: () => context.push(AppRoutes.budgets),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyCta extends StatelessWidget {
  const _EmptyCta({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return InkWell(
      key: TestKeys.budgetsSectionLink,
      onTap: () => context.push(AppRoutes.budgets),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.appColors.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.savings_outlined,
              size: 20,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            const Gap(10),
            Expanded(
              child: Text(
                l10n.budgetsEmptyCta,
                style: context.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
