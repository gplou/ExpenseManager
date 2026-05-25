import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/config/router.dart';
import '../transactions/presentation/screens/add_transaction_screen.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/number_format_provider.dart';
import '../../core/providers/widget_action_provider.dart';
import '../../core/services/home_widget_gateway.dart';
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
import '../../core/services/analytics_service.dart';
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

    _widgetClickedSub = ref.read(homeWidgetGatewayProvider).widgetClicked.listen((uri) {
      if (uri == null || !mounted) return;
      final segments = uri.pathSegments;
      if (segments.isEmpty) return;
      final action = segments.first;
      if (WidgetActions.all.contains(action)) {
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
    if (tutSeen || !mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final shouldStart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppColors.dustyTeal, size: 22),
            const Gap(10),
            Expanded(child: Text(l10n.tutorialDialogTitle)),
          ],
        ),
        content: Text(l10n.tutorialDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.tutorialDialogLaterCta),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dustyTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.tutorialDialogStartCta),
          ),
        ],
      ),
    );

    if (!mounted) return;
    final tutNotifier = ref.read(tutorialProvider.notifier);
    if (shouldStart == true) {
      tutNotifier.start();
    } else {
      await tutNotifier.markSeen();
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
    ref.listen(processRecurringTransactionsProvider, (_, __) {});
    ref.listen(syncProvider, (_, __) {});

    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final period = ref.watch(selectedPeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);
    final summaryAsync = ref.watch(transactionsSummaryProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);
    final cs = context.colors;
    final cSymbol = currencySymbol(ref.watch(currencyProvider).value ?? 'EUR');
    final numFmt = ref.watch(numberFormatProvider).value ??
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
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const Gap(2),
            Text(
              DateTime.now().formattedDate,
              style: context.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        actions: [
          if (ref.watch(isProProvider))
            IconButton(
              key: TutorialKeys.chatBtnKey,
              icon: Icon(Icons.auto_awesome_outlined, color: cs.onSurface),
              tooltip: l10n.chatTitle,
              onPressed: () => context.push(AppRoutes.chat),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
        color: cs.primary,
        backgroundColor: cs.surface,
        onRefresh: () async {
          // Invalida la fuente de verdad → los providers derivados
          // (summary, recent, distribution) se reconstruyen en cascada.
          ref.invalidate(allTransactionsProvider);
          ref.invalidate(processRecurringTransactionsProvider);
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
                                  AnalyticsService.track(AnalyticsService.periodChanged, {'period': p.name});
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
                      skipLoadingOnReload: true,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.recent.toUpperCase(),
                              style: context.textTheme.labelMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: l10n.seeAll,
                            child: InkWell(
                              key: TutorialKeys.seeAllBtnKey,
                              onTap: () => context.push(AppRoutes.transactions),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.seeAll,
                                      style: context.textTheme.labelLarge
                                          ?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Gap(2),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: cs.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(4),
                    recentAsync.when(
                      skipLoadingOnReload: true,
                      loading: () => const _RecentTransactionsShimmer(),
                      error: (e, _) => Text(e.toString()),
                      data: (transactions) {
                        if (transactions.isEmpty) {
                          return _EmptyTransactions(
                            onAdd: () => showAddTransactionSheet(context),
                          );
                        }
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final dividerColor = isDark
                            ? AppColors.dividerDark
                            : AppColors.divider;
                        return Column(
                          children: [
                            for (int i = 0; i < transactions.length; i++) ...[
                              if (i > 0)
                                Container(
                                  height: 1,
                                  color: dividerColor,
                                ),
                              RecentTransactionTile(
                                  transaction: transactions[i]),
                            ],
                          ],
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

// ── Shimmer de transacciones recientes (estado de carga) ─────────────────────

class _RecentTransactionsShimmer extends StatelessWidget {
  const _RecentTransactionsShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final base = cs.onSurface.withValues(alpha: 0.06);
    final highlight = cs.onSurface.withValues(alpha: 0.13);

    return Semantics(
      label: AppLocalizations.of(context).loadingTransactions,
      excludeSemantics: true,
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          children: List.generate(3, (_) => _ShimmerTile()),
        ),
      ),
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        isDark ? AppColors.dividerDark : AppColors.divider;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 12,
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Gap(6),
                Container(
                  height: 10,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 12,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppColors.raisedDark : AppColors.raised,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 24,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const Gap(16),
            Text(
              l10n.noTransactionsPeriod,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const Gap(14),
            Semantics(
              button: true,
              label: l10n.newTransaction,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.newTransaction,
                        style: context.textTheme.labelLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
