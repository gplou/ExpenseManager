import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/custom_date_range_picker.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../transactions/domain/transaction_categories.dart';
import '../../../transactions/domain/transaction_model.dart';
import '../../../transactions/presentation/providers/custom_categories_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../providers/chart_providers.dart';
import '../widgets/chart_widgets.dart';

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

    final accentColor =
        type.isIncome ? AppColors.sageGreen : AppColors.mutedTerra;
    final accentLight =
        type.isIncome ? AppColors.sageGreenLight : AppColors.mutedTerraLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.charts),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Period selector ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
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
                          ref.read(customDateRangeProvider.notifier).state =
                              null;
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
                        ref.read(customDateRangeProvider.notifier).state =
                            range;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const Gap(4),

          // ── Total header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: NeoCard(
              accentColor: accentColor,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      type.isIncome
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _buildTotalLabel(l10n, type, selectedCategory),
                          style: const TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Gap(2),
                        asyncTotal.when(
                          loading: () => Text(
                            '...',
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                          error: (_, __) => Text(
                            l10n.errorLoading,
                            style: TextStyle(color: accentColor),
                          ),
                          data: (total) => Text(
                            '€${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 20,
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
          ),

          // ── Type toggle (Income / Expense) ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TransactionType>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(l10n.typeIncome),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                ),
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(l10n.typeExpense),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                ),
              ],
              selected: {type},
              onSelectionChanged: (s) {
                ref.read(chartTypeFilterProvider.notifier).state = s.first;
                ref.read(chartCategoryFilterProvider.notifier).state = null;
                ref.read(chartSubcategoryFilterProvider.notifier).state = null;
                setState(() => _touchedIndex = null);
              },
            ),
          ),
          const Gap(8),

          // ── Category dropdown ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _CategoryDropdown(
              type: type,
              selectedCategory: selectedCategory,
              customCategories: customCats[type] ?? [],
              l10n: l10n,
              onChanged: (category) {
                ref.read(chartCategoryFilterProvider.notifier).state = category;
                ref.read(chartSubcategoryFilterProvider.notifier).state = null;
                setState(() => _touchedIndex = null);
              },
            ),
          ),
          const Gap(8),

          // ── Chart mode toggle (Pie / Bar) ─────────────────────────────
          SegmentedButton<_ChartMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _ChartMode.pie,
                label: Text('Pie'),
                icon: Icon(Icons.pie_chart_outline, size: 16),
              ),
              ButtonSegment(
                value: _ChartMode.bar,
                label: Text('Bar'),
                icon: Icon(Icons.bar_chart_outlined, size: 16),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _touchedIndex = null;
            }),
          ),
          const Gap(12),

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
                // Replace sentinel key with localized name for display
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
}

// ── Category dropdown ────────────────────────────────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.type,
    required this.selectedCategory,
    required this.customCategories,
    required this.l10n,
    required this.onChanged,
  });

  final TransactionType type;
  final String? selectedCategory;
  final List<TransactionCategory> customCategories;
  final AppLocalizations l10n;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final builtIn = TransactionCategories.forType(type);
    final allCats = [...builtIn, ...customCategories];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedCategory,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                l10n.allCategories,
                style: context.textTheme.bodyMedium,
              ),
            ),
            ...allCats.map((cat) => DropdownMenuItem<String?>(
                  value: cat.name,
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 18),
                      const Gap(8),
                      Text(
                        TransactionCategories.localizedName(cat.name, l10n),
                        style: context.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Period chips ──────────────────────────────────────────────────────────────

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
            color: isSelected ? AppColors.pureWhite : AppColors.textMuted,
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
