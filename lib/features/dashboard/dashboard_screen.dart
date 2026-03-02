import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../core/config/router.dart';
import '../../core/providers/voice_enabled_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/custom_date_range_picker.dart';
import '../../core/widgets/neo_card.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/app_drawer.dart';
import '../transactions/presentation/widgets/voice_transaction_button.dart';
import 'widgets/category_distribution_sheet.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../transactions/domain/transaction_categories.dart';
import '../transactions/domain/transaction_model.dart';
import '../transactions/domain/transactions_repository_contract.dart';
import '../transactions/presentation/providers/recurring_transactions_provider.dart';
import '../transactions/presentation/providers/transactions_provider.dart';
import '../transactions/presentation/screens/add_transaction_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(processRecurringTransactionsProvider);

    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final period = ref.watch(selectedPeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);
    final summaryAsync = ref.watch(transactionsSummaryProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);
    final cs = context.colors;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.greeting(
                user?.name?.split(' ').first ?? l10n.defaultUser,
              ),
              style: context.textTheme.titleLarge,
            ),
            Text(
              DateTime.now().formattedDate,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.38),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ref.watch(voiceEnabledProvider).valueOrNull == true
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const VoiceTransactionButton(),
                const SizedBox(width: 16),
                NeoFab(
                  heroTag: 'addFab',
                  onTap: () => context.push(AppRoutes.addTransaction),
                ),
              ],
            )
          : NeoFab(
              onTap: () => context.push(AppRoutes.addTransaction),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        color: AppColors.dustyTeal,
        backgroundColor: cs.surface,
        onRefresh: () async {
          ref.invalidate(processRecurringTransactionsProvider);
          ref.invalidate(transactionsSummaryProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Selector de período ──────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...TransactionPeriod.values.map((p) {
                      final isSelected = p == period && customRange == null;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _PeriodChip(
                          label: p.l10nLabel(l10n),
                          isSelected: isSelected,
                          onTap: () {
                            ref.read(selectedPeriodProvider.notifier).state = p;
                            ref.read(customDateRangeProvider.notifier).state = null;
                          },
                        ),
                      );
                    }),
                    _IconChip(
                      icon: Icons.calendar_month_outlined,
                      isActive: customRange != null,
                      onTap: () async {
                        final range = await showCustomDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: customRange ??
                              DateTimeRange(
                                start: period.dateRange.from,
                                end: period.dateRange.to,
                              ),
                        );
                        if (range != null) {
                          ref.read(customDateRangeProvider.notifier).state = range;
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Gap(24),

              // ── Balance principal ────────────────────────────────────────
              summaryAsync.when(
                loading: () => const _SummaryShimmer(),
                error: (_, __) => const SizedBox.shrink(),
                data: (summary) => _SummarySection(summary: summary),
              ),
              const Gap(32),

              // ── Transacciones recientes ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.recent.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.4),
                      letterSpacing: 1.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.transactions),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.dustyTealLight,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        l10n.seeAll,
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dustyTeal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              recentAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.dustyTeal),
                ),
                error: (e, _) => Text(e.toString()),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          children: [
                            const Text('📭', style: TextStyle(fontSize: 48)),
                            const Gap(12),
                            Text(
                              l10n.noTransactionsPeriod,
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 14,
                                color: cs.onSurface.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: transactions
                        .map((t) => _RecentTransactionTile(transaction: t))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Period chip ───────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.dustyTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.dustyTeal : AppColors.borderMedium,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.pureWhite
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.warmAmberLight : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? AppColors.warmAmber : AppColors.borderMedium,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? AppColors.warmAmber : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Summary section ───────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});
  final TransactionsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final balance = summary.balance;
    final isPositive = balance >= 0;
    final accentColor = isPositive ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight = isPositive ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

    return Column(
      children: [
        // Balance card principal
        NeoCard(
          accentColor: accentColor,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      l10n.balance.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              Text(
                '${isPositive ? '+' : '-'}€${balance.abs().toStringAsFixed(2)}',
                style: context.textTheme.displaySmall?.copyWith(
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const Gap(4),
              Text(
                isPositive ? '📈' : '📉',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        const Gap(12),
        // Mini cards Ingresos / Gastos
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: l10n.income,
                amount: summary.income,
                accentColor: AppColors.sageGreen,
                accentLight: AppColors.sageGreenLight,
                icon: Icons.arrow_downward_rounded,
                onTap: () => showCategoryDistributionSheet(
                  context,
                  TransactionType.income,
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: _MiniCard(
                label: l10n.expenses,
                amount: summary.expense,
                accentColor: AppColors.mutedTerra,
                accentLight: AppColors.mutedTerraLight,
                icon: Icons.arrow_upward_rounded,
                onTap: () => showCategoryDistributionSheet(
                  context,
                  TransactionType.expense,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.amount,
    required this.accentColor,
    required this.accentLight,
    required this.icon,
    this.onTap,
  });

  final String label;
  final double amount;
  final Color accentColor;
  final Color accentLight;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      accentColor: accentColor,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const Gap(2),
                Text(
                  '€${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _SummaryShimmer extends StatelessWidget {
  const _SummaryShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.softShadow,
          ),
        ),
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.softShadow,
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.softShadow,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Recent transaction tile ───────────────────────────────────────────────────

class _RecentTransactionTile extends ConsumerWidget {
  const _RecentTransactionTile({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final isIncome = transaction.type.isIncome;
    final accentColor = isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight = isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;
    final emoji = _emojiForCategory(transaction.category, isIncome);

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (transaction.description != null)
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
                      else
                        Text(
                          transaction.date.formattedDate,
                          style: const TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 12,
                            color: AppColors.textSubtle,
                          ),
                        ),
                    ],
                  ),
                ),
                const Gap(8),
                Text(
                  '${isIncome ? '+' : '-'}€${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
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
