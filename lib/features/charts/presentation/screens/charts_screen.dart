import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/ad_banner_footer.dart';
import '../../../../core/widgets/custom_date_range_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../transactions/domain/transaction_categories.dart';
import '../../../transactions/domain/transaction_model.dart';
import '../../../transactions/presentation/providers/custom_categories_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../providers/chart_providers.dart';
import '../widgets/chart_widgets.dart';
import '../../../subscription/subscription_provider.dart';

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
    final accentColor =
        type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight =
        type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

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
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Filters section ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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

                const Gap(10),

                // Row 2: Period dropdown + Category dropdown (side by side)
                Row(
                  children: [
                    // Period dropdown
                    Expanded(
                      child: _FilterDropdown(
                        icon: Icons.calendar_today_rounded,
                        label: periodLabel,
                        accentColor: AppColors.dustyTeal,
                        isActive: customRange != null,
                        onTap: () => _showPeriodPicker(
                            context, ref, l10n, period, customRange),
                      ),
                    ),
                    const Gap(10),
                    // Category dropdown
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

                const Gap(10),

                // Row 3: Total card + chart mode toggle
                Row(
                  children: [
                    // Total amount
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accentLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              type.isIncome
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: accentColor,
                              size: 18,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _buildTotalLabel(
                                      l10n, type, selectedCategory),
                                  style: const TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                asyncTotal.when(
                                  loading: () => Text(
                                    '...',
                                    style: TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: accentColor,
                                    ),
                                  ),
                                  error: (_, __) => Text(
                                    l10n.errorLoading,
                                    style: TextStyle(
                                        color: accentColor, fontSize: 12),
                                  ),
                                  data: (total) => Text(
                                    '$cSymbol${total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontFamily: 'Sora',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chart mode toggle (compact icon buttons)
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ChartModeButton(
                            icon: Icons.pie_chart_rounded,
                            isSelected: _mode == _ChartMode.pie,
                            accentColor: accentColor,
                            onTap: () => setState(() {
                              _mode = _ChartMode.pie;
                              _touchedIndex = null;
                            }),
                          ),
                          const Gap(2),
                          _ChartModeButton(
                            icon: Icons.bar_chart_rounded,
                            isSelected: _mode == _ChartMode.bar,
                            accentColor: accentColor,
                            onTap: () => setState(() {
                              _mode = _ChartMode.bar;
                              _touchedIndex = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(8),

          // ── Chart + Legend ─────────────────────────────────────────────
          Expanded(
            child: asyncDistribution.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text(l10n.errorLoading)),
              data: (distribution) {
                if (distribution.isEmpty) {
                  return Center(child: Text(l10n.noDataPeriod));
                }

                final isSubView = selectedCategory != null;
                final displayDistribution = <String, double>{};
                for (final e in distribution.entries) {
                  final key = e.key == '_no_subcategory_'
                      ? l10n.noSubcategory
                      : e.key;
                  displayDistribution[key] = e.value;
                }

                final entries = displayDistribution.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final total =
                    entries.fold<double>(0, (sum, e) => sum + e.value);
                final colors = generateChartColors(entries.length);

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _mode == _ChartMode.pie
                            ? ChartPieSection(
                                key: const ValueKey('pie'),
                                entries: entries,
                                total: total,
                                colors: colors,
                                touchedIndex: _touchedIndex,
                                onTouch: (i) =>
                                    setState(() => _touchedIndex = i),
                              )
                            : ChartBarSection(
                                key: const ValueKey('bar'),
                                entries: entries,
                                colors: colors,
                                type: type,
                                extra: customCats[type] ?? [],
                                isSubcategoryView: isSubView,
                                cSymbol: cSymbol,
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
                      ),
                      const Gap(24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _buildTotalLabel(
      AppLocalizations l10n, TransactionType type, String? category) {
    if (category != null) {
      return TransactionCategories.localizedName(category, l10n);
    }
    return type.isIncome ? l10n.typeIncome : l10n.typeExpense;
  }

  // ── Period picker bottom sheet ──────────────────────────────────────────────

  void _showPeriodPicker(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TransactionPeriod currentPeriod,
    DateTimeRange? currentCustomRange,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(16),
              ...TransactionPeriod.values.map((p) {
                final isSelected =
                    p == currentPeriod && currentCustomRange == null;
                return _PickerOption(
                  icon: _periodIcon(p),
                  label: p.l10nLabel(l10n),
                  isSelected: isSelected,
                  accentColor: AppColors.dustyTeal,
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
                accentColor: AppColors.warmAmber,
                onTap: () async {
                  Navigator.pop(ctx);
                  final range = await showCustomDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(16),
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
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _TypeTab(
              label: l10n.typeIncome,
              icon: Icons.arrow_downward_rounded,
              isSelected: type.isIncome,
              selectedColor: AppColors.sageGreen,
              onTap: () => onChanged(TransactionType.income),
            ),
          ),
          const Gap(3),
          Expanded(
            child: _TypeTab(
              label: l10n.typeExpense,
              icon: Icons.arrow_upward_rounded,
              isSelected: !type.isIncome,
              selectedColor: AppColors.mutedTerra,
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
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textMuted,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.1)
              : context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? accentColor.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? accentColor : AppColors.textMuted,
            ),
            const Gap(8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? accentColor : AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isActive ? accentColor : AppColors.textSubtle,
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
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accentColor : AppColors.textMuted,
            ),
            const Gap(14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? accentColor
                      : context.colors.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: 20,
                color: accentColor,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Chart mode button ─────────────────────────────────────────────────────────

class _ChartModeButton extends StatelessWidget {
  const _ChartModeButton({
    required this.icon,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}
