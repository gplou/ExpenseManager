import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/providers/currency_provider.dart';
import '../../../core/providers/number_format_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../transactions/domain/transaction_categories.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/providers/custom_categories_provider.dart';
import '../../transactions/presentation/screens/add_transaction_screen.dart';

class RecentTransactionTile extends ConsumerWidget {
  const RecentTransactionTile({super.key, required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final isIncome = transaction.type.isIncome;
    final accentColor = isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight = isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;
    final emoji = _emojiForCategory(transaction.category, isIncome);
    final customCats = ref.watch(customCategoriesSyncProvider)[transaction.type] ?? const [];
    IconData? customIcon;
    for (final c in customCats) {
      if (c.name == transaction.category) { customIcon = c.icon; break; }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(transaction: transaction),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.softShadowSm,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accentLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: customIcon != null
                                  ? Icon(customIcon, size: 22, color: accentColor)
                                  : Text(emoji, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  TransactionCategories.localizedName(transaction.category, l10n),
                                  style: TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                                if (transaction.subcategory != null)
                                  Text(
                                    transaction.subcategory!,
                                    style: const TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else if (transaction.description != null)
                                  Text(
                                    transaction.description!,
                                    style: const TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                              ],
                            ),
                          ),
                          const Gap(8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${isIncome ? '+' : '-'}${currencySymbol(ref.watch(currencyProvider).valueOrNull ?? 'EUR')}${formatAmount(transaction.amount, ref.watch(numberFormatProvider).valueOrNull ?? NumberFormatStyle.dotDecimal)}',
                                style: TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                              Text(
                                transaction.date.relativeDateL10n(AppLocalizations.of(context)),
                                style: const TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 11,
                                  color: AppColors.textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
