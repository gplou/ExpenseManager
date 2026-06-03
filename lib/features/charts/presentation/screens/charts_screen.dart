import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_colors.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/core/widgets/ad_banner_footer.dart';
import 'package:expense_manager/core/widgets/custom_date_range_picker.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/features/charts/presentation/providers/chart_providers.dart';
import 'package:expense_manager/features/charts/presentation/widgets/chart_widgets.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';

enum _ChartMode { pie, bar }

class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  _ChartMode _mode = _ChartMode.pie;
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = ref.watch(chartTypeFilterProvider);
    final selectedCategory = ref.watch(chartCategoryFilterProvider);
    final asyncDistribution = ref.watch(chartDistributionProvider);
    final asyncTotal = ref.watch(chartFilteredTotalProvider);
    final customCats = ref.watch(customCategoriesSyncProvider);

    final period = ref.watch(selectedPeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);

    final cSymbol = currencySymbol(ref.watch(currencyProvider).value ?? 'EUR');
    final numFmt = ref.watch(numberFormatProvider).value ??
        NumberFormatStyle.dotDecimal;
    final accentColor =
        type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;

    final builtIn = TransactionCategories.forType(type);
    final allCats = <TransactionCategory>[...builtIn, ...(customCats[type] ?? [])];

    // Period label for the dropdown
    final periodLabel = customRange != null
        ? '${customRange.start.day}/${customRange.start.month} – ${customRange.end.day}/${customRange.end.month}'
        : period.l10nLabel(l10n);

    return Scaffold(
      bottomNavigationBar: ref.watch(isProProvider) ? null : const AdBannerFooter(),
      appBar: AppBar(
        title: Text(l10n.charts),
      ),
      body: Column(
        children: [
          // ── Filters + Stat section ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
            child: Column(
              children: [
                // Row 1: Income/Expense toggle (full width)
                _TypeToggle(
                  type: type,
                  l10n: l10n,
                  onChanged: (t) {
                    ref.read(chartTypeFilterProvider.notifier).state = t;
                    ref.read(chartCategoryFilterProvider.notifier).state = null;
                    ref.read(chartSubcategoryFilterProvider.notifier).state =
                        null;
                    setState(() => _touchedIndex = null);
                  },
                ),

                const Gap(AppSpacing.sm),

                // Row 2: Period dropdown + Category dropdown (side by side)
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        icon: Icons.calendar_today_rounded,
                        label: periodLabel,
                        accentColor: AppColors.inkBlue,
                        isActive: customRange != null,
                        onTap: () => _showPeriodPicker(
                            context, ref, l10n, period, customRange),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Expanded(
                      child: _FilterDropdown(
                        icon: selectedCategory != null
                            ? TransactionCategories.iconFor(
                                selectedCategory, type,
                                extra: customCats[type] ?? [])
                            : Icons.category_rounded,
                        label: selectedCategory != null
                            ? TransactionCategories.localizedName(
                                selectedCategory, l10n)
                            : l10n.allCategories,
                        accentColor: accentColor,
                        isActive: selectedCategory != null,
                        onTap: () => _showCategoryPicker(
                          context,
                          ref,
                          l10n,
                          type,
                          selectedCategory,
                          allCats,
                          accentColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const Gap(AppSpacing.md),

                // Row 3: Stat card (eyebrow + hero number) + chart mode toggle
                _ChartStatCard(
                  eyebrow: _buildEyebrow(
                      l10n, type, selectedCategory, periodLabel),
                  amountAsync: asyncTotal,
                  cSymbol: cSymbol,
                  numFmt: numFmt,
                  accentColor: accentColor,
                  isIncome: type.isIncome,
                  l10n: l10n,
                  mode: _mode,
                  onModeChanged: (m) => setState(() {
                    _mode = m;
                    _touchedIndex = null;
                  }),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.md),

          // ── Chart + Legend ─────────────────────────────────────────────
          Expanded(
            child: _ChartArea(
              asyncDistribution: asyncDistribution,
              l10n: l10n,
              type: type,
              selectedCategory: selectedCategory,
              extra: customCats[type] ?? const [],
              cSymbol: cSymbol,
              numFmt: numFmt,
              mode: _mode,
              touchedIndex: _touchedIndex,
              onTouch: (i) => setState(() => _touchedIndex = i),
            ),
          ),
        ],
      ),
    );
  }

  String _buildEyebrow(
    AppLocalizations l10n,
    TransactionType type,
    String? category,
    String periodLabel,
  ) {
    final main = category != null
        ? TransactionCategories.localizedName(category, l10n)
        : (type.isIncome ? l10n.typeIncome : l10n.typeExpense);
    return '${main.toUpperCase()} · ${periodLabel.toUpperCase()}';
  }

  // ── Period picker bottom sheet ──────────────────────────────────────────────

  void _showPeriodPicker(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TransactionPeriod currentPeriod,
    DateTimeRange? currentCustomRange,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: AppRadius.radiusSheet,
          ),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(AppSpacing.xl),
              ...TransactionPeriod.values.map((p) {
                final isSelected =
                    p == currentPeriod && currentCustomRange == null;
                return _PickerOption(
                  icon: _periodIcon(p),
                  label: p.l10nLabel(l10n),
                  isSelected: isSelected,
                  accentColor: AppColors.inkBlue,
                  onTap: () {
                    ref.read(selectedPeriodProvider.notifier).state = p;
                    ref.read(customDateRangeProvider.notifier).state = null;
                    Navigator.pop(ctx);
                  },
                );
              }),
              _PickerOption(
                icon: Icons.date_range_rounded,
                label: currentCustomRange != null
                    ? '${currentCustomRange.start.day}/${currentCustomRange.start.month}/${currentCustomRange.start.year} – ${currentCustomRange.end.day}/${currentCustomRange.end.month}/${currentCustomRange.end.year}'
                    : l10n.customRange,
                isSelected: currentCustomRange != null,
                accentColor: AppColors.warning,
                onTap: () async {
                  Navigator.pop(ctx);
                  final range = await showCustomDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: clock.now(),
                    initialDateRange: currentCustomRange ??
                        DateTimeRange(
                          start: currentPeriod.dateRange.from,
                          end: currentPeriod.dateRange.to,
                        ),
                  );
                  if (range != null) {
                    ref.read(customDateRangeProvider.notifier).state = range;
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _periodIcon(TransactionPeriod p) {
    switch (p) {
      case TransactionPeriod.week:
        return Icons.view_week_rounded;
      case TransactionPeriod.month:
        return Icons.calendar_month_rounded;
      case TransactionPeriod.year:
        return Icons.calendar_today_rounded;
    }
  }

  // ── Category picker bottom sheet ────────────────────────────────────────────

  void _showCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TransactionType type,
    String? selectedCategory,
    List<TransactionCategory> allCats,
    Color accentColor,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: AppRadius.radiusSheet,
          ),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(AppSpacing.lg),
              Text(
                l10n.category.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const Gap(AppSpacing.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _PickerOption(
                      icon: Icons.grid_view_rounded,
                      label: l10n.allCategories,
                      isSelected: selectedCategory == null,
                      accentColor: accentColor,
                      onTap: () {
                        ref.read(chartCategoryFilterProvider.notifier).state =
                            null;
                        ref
                            .read(chartSubcategoryFilterProvider.notifier)
                            .state = null;
                        setState(() => _touchedIndex = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    ...allCats.map((cat) {
                      final isSelected = selectedCategory == cat.name;
                      return _PickerOption(
                        icon: cat.icon,
                        label: TransactionCategories.localizedName(
                            cat.name, l10n),
                        isSelected: isSelected,
                        accentColor: accentColor,
                        onTap: () {
                          ref
                              .read(chartCategoryFilterProvider.notifier)
                              .state = cat.name;
                          ref
                              .read(chartSubcategoryFilterProvider.notifier)
                              .state = null;
                          setState(() => _touchedIndex = null);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Chart + legend area (handles loading/error/empty/data states) ─────────────

class _ChartArea extends StatelessWidget {
  const _ChartArea({
    required this.asyncDistribution,
    required this.l10n,
    required this.type,
    required this.selectedCategory,
    required this.extra,
    required this.cSymbol,
    required this.numFmt,
    required this.mode,
    required this.touchedIndex,
    required this.onTouch,
  });

  final AsyncValue<Map<String, double>> asyncDistribution;
  final AppLocalizations l10n;
  final TransactionType type;
  final String? selectedCategory;
  final List<TransactionCategory> extra;
  final String cSymbol;
  final NumberFormatStyle numFmt;
  final _ChartMode mode;
  final int? touchedIndex;
  final ValueChanged<int?> onTouch;

  @override
  Widget build(BuildContext context) {
    return asyncDistribution.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(l10n.errorLoading)),
      data: (distribution) {
        if (distribution.isEmpty) {
          return Center(child: Text(l10n.noDataPeriod));
        }

        final isSubView = selectedCategory != null;
        // `distribution` already arrives value-descending from
        // chartDistributionProvider; the display remap preserves order.
        final displayDistribution = <String, double>{};
        for (final e in distribution.entries) {
          final key = e.key == '\x00_no_sub' ? l10n.noSubcategory : e.key;
          displayDistribution[key] = e.value;
        }

        final entries = displayDistribution.entries.toList();
        final total = entries.fold<double>(0, (sum, e) => sum + e.value);
        final colors = generateChartColors(entries.length);

        return SingleChildScrollView(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: mode == _ChartMode.pie
                    ? ChartPieSection(
                        key: const ValueKey('pie'),
                        entries: entries,
                        total: total,
                        colors: colors,
                        touchedIndex: touchedIndex,
                        onTouch: onTouch,
                      )
                    : ChartBarSection(
                        key: const ValueKey('bar'),
                        entries: entries,
                        colors: colors,
                        type: type,
                        extra: extra,
                        isSubcategoryView: isSubView,
                        cSymbol: cSymbol,
                        numFmtStyle: numFmt,
                      ),
              ),
              const Gap(16),
              ChartLegend(
                entries: entries,
                total: total,
                colors: colors,
                l10n: l10n,
                type: type,
                isSubcategoryView: isSubView,
                cSymbol: cSymbol,
                numFmtStyle: numFmt,
              ),
              Gap(MediaQuery.paddingOf(context).bottom + 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Stat card (eyebrow + hero number + chart mode toggle) ─────────────────────

class _ChartStatCard extends StatelessWidget {
  const _ChartStatCard({
    required this.eyebrow,
    required this.amountAsync,
    required this.cSymbol,
    required this.numFmt,
    required this.accentColor,
    required this.isIncome,
    required this.l10n,
    required this.mode,
    required this.onModeChanged,
  });

  final String eyebrow;
  final AsyncValue<double> amountAsync;
  final String cSymbol;
  final NumberFormatStyle numFmt;
  final Color accentColor;
  final bool isIncome;
  final AppLocalizations l10n;
  final _ChartMode mode;
  final ValueChanged<_ChartMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.appColors.divider, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textMuted,
                    letterSpacing: 1.2,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(AppSpacing.sm),
                amountAsync.when(
                  loading: () => Text(
                    '...',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.text,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  error: (_, __) => Text(
                    l10n.errorLoading,
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 13,
                      color: accentColor,
                    ),
                  ),
                  data: (total) => Text(
                    '$cSymbol${formatAmount(total, numFmt)}',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.text,
                      letterSpacing: -0.6,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncome
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 13,
                      color: accentColor,
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      isIncome ? l10n.typeIncome : l10n.typeExpense,
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          _ChartModeSwitch(
            mode: mode,
            onChanged: onModeChanged,
          ),
        ],
      ),
    );
  }
}

// ── Chart mode switch (pie/bar, vertical compact) ─────────────────────────────

class _ChartModeSwitch extends StatelessWidget {
  const _ChartModeSwitch({required this.mode, required this.onChanged});

  final _ChartMode mode;
  final ValueChanged<_ChartMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appColors.raised,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChartModeIcon(
            icon: Icons.pie_chart_rounded,
            isSelected: mode == _ChartMode.pie,
            onTap: () => onChanged(_ChartMode.pie),
          ),
          const Gap(2),
          _ChartModeIcon(
            icon: Icons.bar_chart_rounded,
            isSelected: mode == _ChartMode.bar,
            onTap: () => onChanged(_ChartMode.bar),
          ),
        ],
      ),
    );
  }
}

class _ChartModeIcon extends StatelessWidget {
  const _ChartModeIcon({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? context.appColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md - 3),
          boxShadow: isSelected && !isDark ? AppColors.softShadowSm : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? context.appColors.text : context.appColors.textMuted,
        ),
      ),
    );
  }
}

// ── Type toggle (Income / Expense) — full width ───────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.type,
    required this.l10n,
    required this.onChanged,
  });

  final TransactionType type;
  final AppLocalizations l10n;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.raised,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _TypeTab(
              label: l10n.typeIncome,
              icon: Icons.arrow_downward_rounded,
              isSelected: type.isIncome,
              selectedColor: AppColors.positive,
              onTap: () => onChanged(TransactionType.income),
            ),
          ),
          const Gap(3),
          Expanded(
            child: _TypeTab(
              label: l10n.typeExpense,
              icon: Icons.arrow_upward_rounded,
              isSelected: !type.isIncome,
              selectedColor: AppColors.negative,
              onTap: () => onChanged(TransactionType.expense),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md - 3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.paper : AppColors.graphite,
            ),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: isSelected ? AppColors.paper : AppColors.graphite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter dropdown button ────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isActive;
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
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 11),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isActive ? accentColor : context.appColors.divider,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? accentColor : context.appColors.textMuted,
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.1,
                  color: isActive ? accentColor : context.appColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isActive ? accentColor : context.appColors.textSoft,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Picker option (used in bottom sheets) ─────────────────────────────────────

class _PickerOption extends StatelessWidget {
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accentColor : context.appColors.textMuted,
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.1,
                  color: isSelected ? accentColor : context.appColors.text,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: 18,
                color: accentColor,
              ),
          ],
        ),
      ),
    );
  }
}

