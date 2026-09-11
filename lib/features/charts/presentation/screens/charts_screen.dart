import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/charts/presentation/widgets/chart_area.dart';
import 'package:expense_manager/features/charts/presentation/widgets/chart_filters.dart';
import 'package:expense_manager/features/charts/presentation/widgets/chart_stat_card.dart';

class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  ChartMode _mode = ChartMode.pie;
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
                TypeToggle(
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
                      child: FilterDropdown(
                        icon: PhosphorIcons.calendar(),
                        label: periodLabel,
                        accentColor: AppColors.inkBlue,
                        isActive: customRange != null,
                        onTap: () => _showPeriodPicker(
                            context, ref, l10n, period, customRange),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Expanded(
                      child: FilterDropdown(
                        icon: selectedCategory != null
                            ? TransactionCategories.iconFor(
                                selectedCategory, type,
                                extra: customCats[type] ?? [])
                            : PhosphorIcons.squaresFour(),
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
                ChartStatCard(
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
            child: ChartArea(
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
                return PickerOption(
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
              PickerOption(
                icon: PhosphorIcons.calendarBlank(),
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
        return PhosphorIcons.calendarDots();
      case TransactionPeriod.month:
        return PhosphorIcons.calendarBlank();
      case TransactionPeriod.year:
        return PhosphorIcons.calendar();
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
                  fontFamily: 'Inter',
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
                    PickerOption(
                      icon: PhosphorIcons.squaresFour(),
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
                      return PickerOption(
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
