import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/config/router.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/number_format_provider.dart';
import '../../core/providers/widget_action_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/ad_banner_footer.dart';
import '../../core/widgets/custom_date_range_picker.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/app_drawer.dart';
import 'widgets/dashboard_fab.dart';
import 'widgets/period_selector.dart';
import 'widgets/recent_transaction_tile.dart';
import 'widgets/summary_section.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../transactions/presentation/providers/recurring_transactions_provider.dart';
import '../transactions/presentation/providers/sync_provider.dart';
import '../transactions/presentation/providers/transactions_provider.dart';
import '../subscription/subscription_provider.dart';
import '../tutorial/tutorial_keys.dart';
import '../tutorial/tutorial_notifier.dart';
import '../tutorial/tutorial_overlay.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClickedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _widgetClickedSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri == null || !mounted) return;
      final segments = uri.pathSegments;
      if (segments.isEmpty) return;
      final action = segments.first;
      if (action == 'voice' || action == 'add' || action == 'chat' || action == 'photo') {
        ref.read(pendingWidgetActionProvider.notifier).state = action;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleTutorial());
  }

  void _scheduleTutorial() {
    if (!mounted) return;
    final anim = ModalRoute.of(context)?.animation;
    if (anim != null && !anim.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleTutorial());
      return;
    }
    _startTutorialIfNeeded();
  }

  Future<void> _startTutorialIfNeeded() async {
    if (!mounted) return;
    final tutSeen = await ref.read(tutorialProvider.notifier).hasSeen();
    if (!tutSeen && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) ref.read(tutorialProvider.notifier).start();
    }
  }

  @override
  void dispose() {
    _widgetClickedSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(subscriptionProvider.notifier).forceRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(processRecurringTransactionsProvider);
    ref.watch(syncProvider);

    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final period = ref.watch(selectedPeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);
    final summaryAsync = ref.watch(transactionsSummaryProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);
    final cs = context.colors;
    final cSymbol = currencySymbol(ref.watch(currencyProvider).value ?? 'EUR');
    final numFmt = ref.watch(numberFormatProvider).valueOrNull ??
        NumberFormatStyle.dotDecimal;

    return Stack(
      children: [
      Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: ref.watch(isProProvider) ? null : const AdBannerFooter(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            key: TutorialKeys.drawerBtnKey,
            icon: const Icon(Icons.menu),
            tooltip: MaterialLocalizations.of(ctx).openAppDrawerTooltip,
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
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
        actions: [
          if (ref.watch(isProProvider))
            IconButton(
              key: TutorialKeys.chatBtnKey,
              icon: const Icon(Icons.auto_awesome, color: AppColors.dustyTeal),
              tooltip: l10n.chatTitle,
              onPressed: () => context.push(AppRoutes.chat),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
        color: AppColors.dustyTeal,
        backgroundColor: cs.surface,
        onRefresh: () async {
          ref.invalidate(processRecurringTransactionsProvider);
          ref.invalidate(transactionsSummaryProvider);
          ref.invalidate(recentTransactionsProvider);
          await ref.read(subscriptionProvider.notifier).forceRefresh();
        },
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Period selector ──────────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...TransactionPeriod.values.map((p) {
                            final isSelected = p == period && customRange == null;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: PeriodChip(
                                label: p.l10nLabel(l10n),
                                isSelected: isSelected,
                                onTap: () {
                                  ref.read(selectedPeriodProvider.notifier).state = p;
                                  ref.read(customDateRangeProvider.notifier).state = null;
                                },
                              ),
                            );
                          }),
                          IconChip(
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
                    const Gap(12),

                    // ── Summary ──────────────────────────────────────────────
                    summaryAsync.when(
                      loading: () => const SummaryShimmer(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (summary) => SummarySection(
                        summary: summary,
                        cSymbol: cSymbol,
                        numFmtStyle: numFmt,
                        onViewCharts: () => context.push(AppRoutes.charts),
                      ),
                    ),
                    const Gap(12),

                    // ── Recent transactions ──────────────────────────────────
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
                          key: TutorialKeys.seeAllBtnKey,
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
                    const Gap(8),
                    recentAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.dustyTeal),
                      ),
                      error: (e, _) => Text(e.toString()),
                      data: (transactions) {
                        if (transactions.isEmpty) {
                          return _EmptyTransactions(
                            onAdd: () => context.push(AppRoutes.addTransaction),
                          );
                        }
                        return Column(
                          children: transactions
                              .map((t) => RecentTransactionTile(transaction: t))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
                  ),
            const Gap(12),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    ),
  ),
      ),
          const Positioned.fill(
            child: SpeedDialFab(),
          ),
        ],
      ),
      ),

      const TutorialOverlay(),
      ],
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.dustyTealLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('\u{1f4ed}', style: TextStyle(fontSize: 32)),
              ),
            ),
            const Gap(16),
            Text(
              l10n.noTransactionsPeriod,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(8),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.dustyTealLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 16, color: AppColors.dustyTeal),
                    const Gap(4),
                    Text(
                      l10n.newTransaction,
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dustyTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
