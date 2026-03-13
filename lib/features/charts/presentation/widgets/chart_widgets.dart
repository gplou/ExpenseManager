import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../transactions/domain/transaction_categories.dart';
import '../../../transactions/domain/transaction_model.dart';

// ── Colors ───────────────────────────────────────────────────────────────────

const _baseChartColors = [
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

List<Color> generateChartColors(int count) =>
    List.generate(count, (i) => _baseChartColors[i % _baseChartColors.length]);

// ── Pie chart ────────────────────────────────────────────────────────────────

class ChartPieSection extends StatelessWidget {
  const ChartPieSection({
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

// ── Bar chart ────────────────────────────────────────────────────────────────

class ChartBarSection extends StatelessWidget {
  const ChartBarSection({
    super.key,
    required this.entries,
    required this.colors,
    required this.type,
    this.extra = const [],
    this.isSubcategoryView = false,
    this.cSymbol = '€',
  });

  final List<MapEntry<String, double>> entries;
  final List<Color> colors;
  final TransactionType type;
  final List<TransactionCategory> extra;
  final bool isSubcategoryView;
  final String cSymbol;

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
                '$cSymbol${rod.toY.toStringAsFixed(2)}',
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
                  if (isSubcategoryView) {
                    // For subcategories, show abbreviated text
                    final name = entries[i].key;
                    final short =
                        name.length > 4 ? '${name.substring(0, 4)}.' : name;
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        short,
                        style: TextStyle(
                          fontSize: 9,
                          color: colors[i],
                        ),
                      ),
                    );
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
                      '$cSymbol${value.toStringAsFixed(0)}',
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
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

class ChartLegend extends StatelessWidget {
  const ChartLegend({
    super.key,
    required this.entries,
    required this.total,
    required this.colors,
    required this.l10n,
    required this.type,
    this.isSubcategoryView = false,
    this.cSymbol = '€',
  });

  final List<MapEntry<String, double>> entries;
  final double total;
  final List<Color> colors;
  final AppLocalizations l10n;
  final TransactionType type;
  final bool isSubcategoryView;
  final String cSymbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final pct = (entry.value / total * 100).toStringAsFixed(1);
          final name = isSubcategoryView
              ? entry.key
              : TransactionCategories.localizedName(entry.key, l10n);
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
                  child: Text(name, style: context.textTheme.bodyMedium),
                ),
                Text(
                  '$pct%',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const Gap(8),
                Text(
                  '$cSymbol${entry.value.toStringAsFixed(2)}',
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
