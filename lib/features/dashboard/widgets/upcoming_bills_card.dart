import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/presentation/providers/recurring_transactions_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Resumen de lo que se va a cargar próximamente: importe total y los
/// primeros nombres.
///
/// Se oculta del todo cuando no hay nada programado — una tarjeta vacía en
/// el dashboard es ruido, no información.
class UpcomingBillsCard extends ConsumerWidget {
  const UpcomingBillsCard({
    super.key,
    required this.cSymbol,
    required this.numFmtStyle,
    this.onTap,
  });

  final String cSymbol;
  final NumberFormatStyle numFmtStyle;
  final VoidCallback? onTap;

  /// Nombres que caben en el subtítulo antes de resumir con "+N".
  static const _maxNames = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingRecurringProvider).value;
    if (upcoming == null || upcoming.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final appColors = context.appColors;

    final total = upcoming.fold<double>(0, (sum, r) => sum + r.amount);
    final names = upcoming
        .take(_maxNames)
        .map((r) => r.description?.trim().isNotEmpty == true
            ? r.description!.trim()
            : TransactionCategories.localizedName(r.category, l10n))
        .toList();
    final extra = upcoming.length - names.length;
    final subtitle =
        extra > 0 ? '${names.join(' · ')} +$extra' : names.join(' · ');

    return Material(
      color: appColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: appColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(PhosphorIcons.repeat(),
                    size: 20, color: cs.primary),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.upcomingBills,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const Gap(2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: appColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(8),
              Text(
                '$cSymbol${formatAmount(total, numFmtStyle)}',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (onTap != null) ...[
                const Gap(4),
                Icon(PhosphorIcons.caretRight(),
                    size: 16, color: appColors.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
