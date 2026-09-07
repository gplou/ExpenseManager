import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/screens/add_transaction_screen.dart';

/// Fila editorial Quiet Wealth: hairline divider entre filas (sin border-box),
/// avatar circular en raised cálido, tipografía calmada, números tabulares.
class RecentTransactionTile extends ConsumerWidget {
  const RecentTransactionTile({super.key, required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final tt = context.textTheme;
    final isIncome = transaction.type.isIncome;

    final amountColor = isIncome ? AppColors.positive : AppColors.negative;
    final avatarBg = context.appColors.raised;
    final secondaryText = context.appColors.textMuted;

    final emoji = _emojiForCategory(transaction.category, isIncome);
    final customCats =
        ref.watch(customCategoriesSyncProvider)[transaction.type] ?? const [];
    TransactionCategory? customCat;
    for (final c in customCats) {
      if (c.name == transaction.category) {
        customCat = c;
        break;
      }
    }

    final amountStr =
        '${isIncome ? '+' : '-'}${currencySymbol(ref.watch(currencyProvider).value ?? 'EUR')}${formatAmount(transaction.amount, ref.watch(numberFormatProvider).value ?? NumberFormatStyle.dotDecimal)}';

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        showAddTransactionSheet(context, transaction: transaction);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            // ── Avatar ────────────────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: customCat != null
                    ? customCat.emojiOverride != null
                        ? Text(customCat.emojiOverride!,
                            style: const TextStyle(fontSize: AppEmojiSize.medium))
                        : Icon(customCat.icon,
                            size: 18, color: cs.onSurface)
                    : Text(emoji,
                        style: const TextStyle(fontSize: AppEmojiSize.medium)),
              ),
            ),
            const Gap(14),

            // ── Categoría + subtítulo ─────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    TransactionCategories.localizedName(
                        transaction.category, l10n),
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (transaction.subcategory != null) ...[
                    const Gap(2),
                    Text(
                      transaction.subcategory!,
                      style: tt.bodySmall?.copyWith(color: secondaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (transaction.description != null) ...[
                    const Gap(2),
                    Text(
                      transaction.description!,
                      style: tt.bodySmall?.copyWith(color: secondaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Gap(12),

            // ── Importe + fecha ───────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  amountStr,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                    letterSpacing: -0.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Gap(2),
                Text(
                  transaction.date
                      .pastDateL10n(AppLocalizations.of(context)),
                  style: tt.bodySmall?.copyWith(
                    color: secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
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
