import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/utils/extensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../transactions/domain/transaction_categories.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/providers/custom_categories_provider.dart';
import '../../transactions/presentation/providers/transactions_provider.dart';

enum _ChartMode { pie, bar }

void showCategoryDistributionSheet(
  BuildContext context,
  TransactionType type,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CategoryDistributionSheet(type: type),
  );
}

class _CategoryDistributionSheet extends ConsumerStatefulWidget {
  const _CategoryDistributionSheet({required this.type});
  final TransactionType type;

  @override
  ConsumerState<_CategoryDistributionSheet> createState() =>
      _CategoryDistributionSheetState();
}

class _CategoryDistributionSheetState
    extends ConsumerState<_CategoryDistributionSheet> {
  _ChartMode _mode = _ChartMode.pie;
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncData = ref.watch(categoryDistributionProvider(widget.type));
    final customCats = ref.watch(customCategoriesProvider);
    final title =
        widget.type.isIncome ? l10n.incomeDistribution : l10n.expenseDistribution;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const Gap(16),
          Text(title, style: context.textTheme.titleLarge),
          const Gap(12),
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
          const Gap(16),
          Expanded(
            child: asyncData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text(l10n.errorLoading)),
              data: (distribution) {
                if (distribution.isEmpty) {
                  return Center(child: Text(l10n.noDataPeriod));
                }
                final entries = distribution.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final total =
                    entries.fold<double>(0, (sum, e) => sum + e.value);
                final colors = _generateColors(entries.length);

                return SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _mode == _ChartMode.pie
                            ? _PieChartSection(
                                key: const ValueKey(_ChartMode.pie),
                                entries: entries,
                                total: total,
                                colors: colors,
                                touchedIndex: _touchedIndex,
                                onTouch: (i) =>
                                    setState(() => _touchedIndex = i),
                              )
                            : _BarChartSection(
                                key: const ValueKey(_ChartMode.bar),
                                entries: entries,
                                colors: colors,
                                type: widget.type,
                                extra: customCats[widget.type] ?? [],
                              ),
                      ),
                      const Gap(16),
                      _Legend(
                        entries: entries,
                        total: total,
                        colors: colors,
                        l10n: l10n,
                        type: widget.type,
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

  List<Color> _generateColors(int count) {
    const baseColors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFFF97316),
    ];
    return List.generate(count, (i) => baseColors[i % baseColors.length]);
  }
}

// ── Pie chart ─────────────────────────────────────────────────────────────────

class _PieChartSection extends StatelessWidget {
  const _PieChartSection({
    super.key,
    required this.entries,
    required this.total,
    required this.colors,
    required this.touchedIndex,
    required this.onTouch,
  });

  final List<MapEntry<String, double>> entries;
  final double total;
  final List<Color> colors;
  final int? touchedIndex;
  final ValueChanged<int?> onTouch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions ||
                  response == null ||
                  response.touchedSection == null) {
                onTouch(null);
                return;
              }
              onTouch(response.touchedSection!.touchedSectionIndex);
            },
          ),
          sectionsSpace: 2,
          centerSpaceRadius: 48,
          sections: List.generate(entries.length, (i) {
            final isTouched = touchedIndex == i;
            final pct = (entries[i].value / total * 100).toStringAsFixed(1);
            return PieChartSectionData(
              color: colors[i],
              value: entries[i].value,
              title: isTouched ? '$pct%' : '',
              radius: isTouched ? 80 : 64,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChartSection extends StatelessWidget {
  const _BarChartSection({
    super.key,
    required this.entries,
    required this.colors,
    required this.type,
    this.extra = const [],
  });

  final List<MapEntry<String, double>> entries;
  final List<Color> colors;
  final TransactionType type;
  final List<TransactionCategory> extra;

  @override
  Widget build(BuildContext context) {
    final maxY = entries.isEmpty
        ? 100.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                '€${rod.toY.toStringAsFixed(2)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  final icon = TransactionCategories.iconFor(
                      entries[i].key, type,
                      extra: extra);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Icon(icon, size: 14, color: colors[i]),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '€${value.toStringAsFixed(0)}',
                      style: context.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color:
                            context.colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: context.colors.onSurface.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            entries.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  color: colors[i],
                  width: 20,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({
    required this.entries,
    required this.total,
    required this.colors,
    required this.l10n,
    required this.type,
  });

  final List<MapEntry<String, double>> entries;
  final double total;
  final List<Color> colors;
  final AppLocalizations l10n;
  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final pct = (entry.value / total * 100).toStringAsFixed(1);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    TransactionCategories.localizedName(entry.key, l10n),
                    style: context.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '$pct%',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const Gap(8),
                Text(
                  '€${entry.value.toStringAsFixed(2)}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
