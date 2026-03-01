import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../core/config/router.dart';
import '../../core/providers/voice_enabled_provider.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/custom_date_range_picker.dart';
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
    // Procesa recurrentes pendientes al abrir la app (una vez por sesión)
    ref.watch(processRecurringTransactionsProvider);

    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final period = ref.watch(selectedPeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);
    final summaryAsync = ref.watch(transactionsSummaryProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);

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
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.5),
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
                FloatingActionButton(
                  heroTag: 'addFab',
                  onPressed: () => context.push(AppRoutes.addTransaction),
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : FloatingActionButton(
              onPressed: () => context.push(AppRoutes.addTransaction),
              child: const Icon(Icons.add),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(processRecurringTransactionsProvider);
          ref.invalidate(transactionsSummaryProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Selector de período ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...TransactionPeriod.values.map((p) {
                    final isSelected = p == period && customRange == null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(p.l10nLabel(l10n)),
                        selected: isSelected,
                        onSelected: (_) {
                          ref.read(selectedPeriodProvider.notifier).state = p;
                          ref.read(customDateRangeProvider.notifier).state =
                              null;
                        },
                      ),
                    );
                  }),
                  IconButton(
                    icon: Icon(
                      Icons.calendar_month_outlined,
                      color: customRange != null
                          ? context.colors.primary
                          : null,
                    ),
                    tooltip: l10n.customRange,
                    onPressed: () async {
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
                        ref.read(customDateRangeProvider.notifier).state =
                            range;
                      }
                    },
                  ),
                ],
              ),
              const Gap(24),

              // ── Balance principal ────────────────────────────────────────
              summaryAsync.when(
                loading: () => const _SummaryShimmer(),
                error: (_, __) => const SizedBox.shrink(),
                data: (summary) => _SummarySection(summary: summary),
              ),
              const Gap(28),

              // ── Transacciones recientes ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.recent, style: context.textTheme.titleMedium),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.transactions),
                    child: Text(l10n.seeAll),
                  ),
                ],
              ),
              const Gap(8),
              recentAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(e.toString()),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: context.colors.onSurface
                                  .withValues(alpha: 0.3),
                            ),
                            const Gap(12),
                            Text(
                              l10n.noTransactionsPeriod,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colors.onSurface
                                    .withValues(alpha: 0.4),
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

// ── Summary section ───────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});
  final TransactionsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final balance = summary.balance;
    final isPositive = balance >= 0;

    return Column(
      children: [
        // Balance card grande
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPositive
                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                  : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                l10n.balance,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Gap(8),
              Text(
                '${isPositive ? '+' : ''}€${balance.abs().toStringAsFixed(2)}',
                style: context.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Gap(16),
        // Ingresos y gastos
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: l10n.income,
                amount: summary.income,
                icon: Icons.arrow_downward_rounded,
                color: Colors.green,
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
                icon: Icons.arrow_upward_rounded,
                color: Colors.red,
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
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '€${amount.toStringAsFixed(2)}',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.pie_chart_outline,
                  size: 14,
                  color: context.colors.onSurface.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _SummaryShimmer extends StatelessWidget {
  const _SummaryShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 130,
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
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

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isIncome = transaction.type.isIncome;
    final color = isIncome ? Colors.green : Colors.red;
    final icon = TransactionCategories.iconFor(
      transaction.category,
      transaction.type,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(transaction: transaction),
        ),
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        TransactionCategories.localizedName(transaction.category, l10n),
        style: context.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: transaction.description != null
          ? Text(
              transaction.description!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              transaction.date.formattedDate,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
      trailing: Text(
        '${isIncome ? '+' : '-'}€${transaction.amount.toStringAsFixed(2)}',
        style: context.textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
