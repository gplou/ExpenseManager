import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/config/router.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/number_format_provider.dart';
import '../../core/providers/widget_action_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/ad_banner_footer.dart';
import '../../core/widgets/custom_date_range_picker.dart';
import '../../core/widgets/neo_card.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/app_drawer.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../transactions/data/voice_transaction_parser.dart';
import '../transactions/data/image_transaction_parser.dart';
import '../transactions/domain/parsed_voice_transaction.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../transactions/domain/transaction_categories.dart';
import '../transactions/domain/transaction_model.dart';
import '../transactions/domain/transactions_repository_contract.dart';
import '../transactions/presentation/providers/custom_categories_provider.dart';
import '../transactions/presentation/providers/recurring_transactions_provider.dart';
import '../transactions/presentation/providers/transactions_provider.dart';
import '../transactions/presentation/screens/add_transaction_screen.dart';
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


    // Escuchar taps del widget mientras la app ya está en ejecución
    _widgetClickedSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri == null || !mounted) return;
      final segments = uri.pathSegments;
      if (segments.isEmpty) return;
      final action = segments.first;
      if (action == 'voice' || action == 'add') {
        ref.read(pendingWidgetActionProvider.notifier).state = action;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleTutorial());
  }

  // Waits frame-by-frame until the incoming route animation is complete before
  // starting the tutorial, so the spotlight is measured on a fully-settled layout.
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
        // Custom leading so we can attach a GlobalKey for the tutorial spotlight.
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
                    const Gap(12),

                    // ── Balance principal ────────────────────────────────────────
                    summaryAsync.when(
                      loading: () => const _SummaryShimmer(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (summary) => _SummarySection(summary: summary, cSymbol: cSymbol, numFmtStyle: numFmt),
                    ),
                    const Gap(12),

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
                                      child: Text('📭', style: TextStyle(fontSize: 32)),
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
                                    onTap: () => context.push(AppRoutes.addTransaction),
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
            const Gap(12),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    ),
  ),
      ),
          // ── Speed dial overlay (backdrop + radial buttons) ─────────────
          const Positioned.fill(
            child: _SpeedDialFab(),
          ),
        ],
      ),
      ), // ── End Scaffold ──────────────────────────────────────────────────

      // ── Interactive tutorial overlay (covers AppBar + body) ──────────────
      const TutorialOverlay(),
      ],
    ); // ── End outer Stack ──────────────────────────────────────────────────
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
  const _SummarySection({
    required this.summary,
    required this.cSymbol,
    required this.numFmtStyle,
  });
  final TransactionsSummary summary;
  final String cSymbol;
  final NumberFormatStyle numFmtStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = summary.balance;
    final isPositive = balance >= 0;
    final accentColor = isPositive ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight = isPositive ? AppColors.sageGreenLight : AppColors.mutedTerraLight;
    final total = summary.income + summary.expense;
    final incomePercent = total > 0 ? (summary.income / total * 100).round() : 0;
    final expensePercent = total > 0 ? (summary.expense / total * 100).round() : 0;

    return Column(
      children: [
        // Balance card unificada
        Container(
          key: TutorialKeys.balanceCardKey,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      accentLight.withValues(alpha: 0.18),
                      AppColors.darkSurface,
                    ]
                  : [
                      accentLight.withValues(alpha: 0.45),
                      cs.surface,
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: isDark
                ? Border.all(color: cs.outline, width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.08 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              if (!isDark)
                const BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
            ],
          ),
          child: Column(
            children: [
              // Badge de balance
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: accentColor,
                    ),
                    const Gap(4),
                    Text(
                      l10n.balance.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(10),
              // Monto del balance
              Text(
                '${isPositive ? '' : '-'}$cSymbol${formatAmount(balance.abs(), numFmtStyle)}',
                style: context.textTheme.headlineLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (total > 0) ...[
                const Gap(12),
                // Barra de proporción
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: SizedBox(
                    height: 5,
                    child: Row(
                      children: [
                        Expanded(
                          flex: incomePercent.clamp(1, 99),
                          child: Container(color: AppColors.sageGreen),
                        ),
                        const Gap(2),
                        Expanded(
                          flex: expensePercent.clamp(1, 99),
                          child: Container(color: AppColors.mutedTerra),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const Gap(12),
              // Separador sutil
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? AppColors.darkBorderColor.withValues(alpha: 0.5)
                    : AppColors.borderLight.withValues(alpha: 0.7),
              ),
              const Gap(12),
              // Fila de ingresos y gastos
              Row(
                children: [
                  // Ingresos
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.sageGreen.withValues(alpha: isDark ? 0.15 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.south_west_rounded,
                            size: 16,
                            color: AppColors.sageGreen,
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.income,
                                style: TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                '$cSymbol${formatAmount(summary.income, numFmtStyle)}',
                                style: const TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sageGreen,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Divisor vertical
                  Container(
                    width: 1,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: isDark
                        ? AppColors.darkBorderColor.withValues(alpha: 0.5)
                        : AppColors.borderLight.withValues(alpha: 0.7),
                  ),
                  // Gastos
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.mutedTerra.withValues(alpha: isDark ? 0.15 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.north_east_rounded,
                            size: 16,
                            color: AppColors.mutedTerra,
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.expenses,
                                style: TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                '$cSymbol${formatAmount(summary.expense, numFmtStyle)}',
                                style: const TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mutedTerra,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(12),
        // Charts button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: TutorialKeys.chartsBtnKey,
            onPressed: () => context.push(AppRoutes.charts),
            icon: const Icon(Icons.pie_chart_outline, size: 18),
            label: Text(l10n.viewCharts),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dustyTeal,
              side: const BorderSide(color: AppColors.dustyTeal, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _SummaryShimmer extends StatelessWidget {
  const _SummaryShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkSurfaceHigh : const Color(0xFFECEAE4);
    final highlightColor = isDark ? AppColors.darkSurface.withValues(alpha: 0.7) : const Color(0xFFF8F7F2);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 185,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const Gap(12),
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
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
                  // Barra lateral de acento
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

// ── Speed dial FAB ────────────────────────────────────────────────────────────

enum _VoiceInputState { idle, listening, processing, cameraProcessing }

class _SpeedDialFab extends ConsumerStatefulWidget {
  const _SpeedDialFab();

  @override
  ConsumerState<_SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends ConsumerState<_SpeedDialFab> {
  bool _open = false;
  _VoiceInputState _voiceState = _VoiceInputState.idle;
  bool _handledInitialWidgetAction = false;

  final _speech = SpeechToText();
  final _parser = VoiceTransactionParser();
  final _imagePicker = ImagePicker();
  final _imageParser = ImageTransactionParser();

  @override
  void initState() {
    super.initState();
    // Acción de widget al lanzar la app por primera vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _handledInitialWidgetAction) return;
      final action = ref.read(pendingWidgetActionProvider);
      if (action != null) {
        _handledInitialWidgetAction = true;
        _handleWidgetAction(action);
        ref.read(pendingWidgetActionProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  void _handleWidgetAction(String action) {
    if (action == 'voice') {
      _startVoice();
    } else if (action == 'add') {
      context.push(AppRoutes.addTransaction);
    }
  }

  void _toggle() => setState(() => _open = !_open);

  void _closeDial() {
    if (_open) setState(() => _open = false);
  }

  Future<void> _startVoice() async {
    _closeDial();

    final available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _voiceState = _VoiceInputState.idle);
      },
    );

    if (!available) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.micUnavailable)),
        );
      }
      return;
    }

    setState(() => _voiceState = _VoiceInputState.listening);

    await _speech.listen(
      localeId: 'es_ES',
      onResult: (result) {
        if (result.finalResult) _processVoice(result.recognizedWords);
      },
    );
  }

  Future<void> _processVoice(String text) async {
    if (text.trim().isEmpty) {
      if (mounted) setState(() => _voiceState = _VoiceInputState.idle);
      return;
    }
    setState(() => _voiceState = _VoiceInputState.processing);
    ParsedVoiceTransaction? parsed;
    try {
      parsed = await _parser.parse(text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _voiceState = _VoiceInputState.idle);
      final info = e.toString().split('\n').first;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voiceAiError(e.runtimeType.toString(), info))),
      );
      return;
    }
    if (!mounted) return;
    if (parsed == null) {
      setState(() => _voiceState = _VoiceInputState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).voiceInterpretError),
        ),
      );
      return;
    }
    // Stop the speech session completely before navigating.
    // On iOS, keeping it active can block gesture recognition on the next screen.
    await _speech.stop();
    setState(() => _voiceState = _VoiceInputState.idle);
    if (!mounted) return;
    context.push(AppRoutes.addTransaction, extra: parsed);
  }

  Future<void> _startCamera() async {
    _closeDial();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(l10n.cameraOption),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(l10n.galleryOption),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;
    await _processImage(picked);
  }

  Future<void> _processImage(XFile pickedFile) async {
    if (!mounted) return;
    setState(() => _voiceState = _VoiceInputState.cameraProcessing);

    File? tempFile;
    try {
      tempFile = File(pickedFile.path);
      final imageBytes = await tempFile.readAsBytes();

      final ParsedVoiceTransaction? parsed = await _imageParser.parse(imageBytes);

      if (!mounted) return;
      setState(() => _voiceState = _VoiceInputState.idle);

      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).imageTransactionNotDetected),
          ),
        );
        return;
      }
      context.push(AppRoutes.addTransaction, extra: parsed);
    } catch (e) {
      if (mounted) {
        setState(() => _voiceState = _VoiceInputState.idle);
        final info = e.toString().split('\n').first;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.imageAiError(e.runtimeType.toString(), info))),
        );
      }
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  // ── Layout constants ──────────────────────────────────────────────────────
  //
  //  Stack size: 220 × 175 px
  //  FAB (64 px) → bottom-centre of the Stack: centre at (110, 143)
  //  Mini buttons (50 px) on a circle of r = 85 px, ±65° and 0° from straight-up:
  //
  //           [🎤]   [✏️]   [📷]
  //             \     |     /
  //              \    |    /    ← r = 85 px
  //               \   |   /
  //                  [+]
  //
  //  Mic    → centre (33, 107)  = FAB centre + (−77, −36)
  //  Pencil → centre (110, 58)  = FAB centre + (  0, −85)
  //  Camera → centre (187, 107) = FAB centre + (+77, −36)
  static const double _stackW   = 220;
  static const double _stackH   = 175;
  static const double _fabSize  =  64;
  static const double _miniSize =  50;

  // FAB centre inside the Stack (Stack coords: origin = top-left)
  static const double _fabCx = _stackW / 2;             // 110
  static const double _fabCy = _stackH - _fabSize / 2;  // 143

  // Mini-button target centres when open
  static const Offset _micTarget    = Offset(33,  107);
  static const Offset _pencilTarget = Offset(110,  58);
  static const Offset _cameraTarget = Offset(187, 107);

  // Starting position: collapsed at the FAB centre
  static const Offset _closedPos = Offset(_fabCx, _fabCy);

  // Convert a centre-Offset to AnimatedPositioned.left
  static double _left(Offset c)   => c.dx - _miniSize / 2;
  // Convert a centre-Offset to AnimatedPositioned.bottom
  static double _bottom(Offset c) => _stackH - c.dy - _miniSize / 2;

  @override
  Widget build(BuildContext context) {
    // ── Acción de widget (app en background que vuelve al frente) ─────────────
    ref.listen<String?>(pendingWidgetActionProvider, (_, action) {
      if (action == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleWidgetAction(action);
        ref.read(pendingWidgetActionProvider.notifier).state = null;
      });
    });

    // ── Tutorial: auto-open dial for steps 1-3 (voice/manual/camera) ─────────
    final tutStep = ref.watch(
      tutorialProvider.select((s) => s.isActive ? s.stepIndex : -1),
    );
    final tutNeedsDialOpen = tutStep >= 1 && tutStep <= 3;
    if (tutNeedsDialOpen && !_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_open) setState(() => _open = true);
      });
    } else if (tutStep >= 4 && _open) {
      // Tutorial has moved past the dial steps → close it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) setState(() => _open = false);
      });
    }

    final l10n = AppLocalizations.of(context);

    // Distance from the bottom of the body area to the FAB bottom edge,
    // matching Flutter's standard centerFloat margin.
    final fabBottom =
        MediaQuery.of(context).padding.bottom + 16.0;

    // ── Voice active: show mic state widget centred at FAB position ──────────
    if (_voiceState != _VoiceInputState.idle) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            bottom: fabBottom,
            left: 0,
            right: 0,
            child: Center(child: _buildVoiceWidget()),
          ),
        ],
      );
    }

    // ── Normal state: backdrop + radial speed dial ───────────────────────────
    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop — absorbs ALL pointer events when open (blocks scroll/swipe too)
        IgnorePointer(
          ignoring: !_open,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _open ? 1.0 : 0.0,
            child: GestureDetector(
              onTap: _closeDial,
              // opaque → swallows drags/scrolls as well
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),

        // Speed dial (positioned at the same spot as standard centerFloat FAB)
        Positioned(
          bottom: fabBottom,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: _stackW,
              height: _stackH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Mini radial buttons (behind the FAB)
                  _radialButton(
                    context,
                    tutorialKey: TutorialKeys.voiceBtnKey,
                    icon: Icons.mic_outlined,
                    label: l10n.labelVoice,
                    target: _micTarget,
                    onTap: _startVoice,
                  ),
                  _radialButton(
                    context,
                    tutorialKey: TutorialKeys.manualBtnKey,
                    icon: Icons.edit_outlined,
                    label: l10n.labelManual,
                    target: _pencilTarget,
                    onTap: () {
                      _closeDial();
                      context.push(AppRoutes.addTransaction);
                    },
                  ),
                  _radialButton(
                    context,
                    tutorialKey: TutorialKeys.cameraBtnKey,
                    icon: Icons.camera_alt_outlined,
                    label: l10n.labelPhoto,
                    target: _cameraTarget,
                    onTap: _startCamera,
                  ),
                  // Main FAB (always on top)
                  Positioned(
                    left: (_stackW - _fabSize) / 2,
                    bottom: 0,
                    child: SizedBox(
                      key: TutorialKeys.fabKey,
                      width: _fabSize,
                      height: _fabSize,
                      child: NeoFab(
                        icon: _open ? Icons.close : Icons.add,
                        onTap: _toggle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds one mini button that animates radially from the FAB centre.
  Widget _radialButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Offset target,
    required VoidCallback onTap,
    GlobalKey? tutorialKey,
  }) {
    final centre = _open ? target : _closedPos;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      left:   _left(centre),
      bottom: _bottom(centre),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _open ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_open,
          child: _MiniDialButton(
            key: tutorialKey,
            icon: icon,
            label: label,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceWidget() {
    if (_voiceState == _VoiceInputState.processing ||
        _voiceState == _VoiceInputState.cameraProcessing) {
      return Container(
        width: _fabSize,
        height: _fabSize,
        decoration: const BoxDecoration(
          color: AppColors.dustyTeal,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    // Listening → red stop button
    return GestureDetector(
      onTap: () async {
        await _speech.stop();
        if (mounted) setState(() => _voiceState = _VoiceInputState.idle);
      },
      child: Container(
        width: _fabSize,
        height: _fabSize,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Mini radial button ────────────────────────────────────────────────────────

class _MiniDialButton extends StatelessWidget {
  const _MiniDialButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.dustyTeal,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.dustyTeal.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const Gap(4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
