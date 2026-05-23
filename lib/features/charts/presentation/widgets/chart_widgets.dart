import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/providers/number_format_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../transactions/domain/transaction_categories.dart';
import '../../../transactions/domain/transaction_model.dart';

// ── Colors ───────────────────────────────────────────────────────────────────
//
// Paleta curada Quiet Wealth — todos los colores con saturación moderada para
// convivir en charts sin chillar. Misma escala que se usa en el resto del UI.

List<Color> generateChartColors(int count) =>
    List.generate(count,
        (i) => AppColors.categoryScale[i % AppColors.categoryScale.length]);

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
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 260,
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
          sectionsSpace: 3,
          centerSpaceRadius: 70,
          startDegreeOffset: -90,
          sections: List.generate(entries.length, (i) {
            final isTouched = touchedIndex == i;
            final pct = (entries[i].value / total * 100).toStringAsFixed(1);
            return PieChartSectionData(
              color: colors[i],
              value: entries[i].value,
              title: isTouched ? '$pct%' : '',
              radius: isTouched ? 64 : 52,
              titleStyle: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.surface,
                letterSpacing: -0.2,
              ),
            );
          }),
        ),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
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
    this.numFmtStyle = NumberFormatStyle.dotDecimal,
  });

  final List<MapEntry<String, double>> entries;
  final List<Color> colors;
  final TransactionType type;
  final List<TransactionCategory> extra;
  final bool isSubcategoryView;
  final String cSymbol;
  final NumberFormatStyle numFmtStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = context.textTheme;
    final maxY = entries.isEmpty
        ? 100.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                '$cSymbol${formatAmount(rod.toY, numFmtStyle)}',
                TextStyle(
                  fontFamily: 'GeneralSans',
                  color: cs.surface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: -0.1,
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
                    final name = entries[i].key;
                    final short =
                        name.length > 4 ? '${name.substring(0, 4)}.' : name;
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        short,
                        style: tt.labelSmall?.copyWith(
                          color: colors[i],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  final icon = TransactionCategories.iconFor(
                      entries[i].key, type,
                      extra: extra);
                  return SideTitleWidget(
                    meta: meta,
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
                    meta: meta,
                    child: Text(
                      '$cSymbol${formatAmount(value, numFmtStyle, decimals: 0)}',
                      style: tt.bodySmall?.copyWith(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontFeatures: const [FontFeature.tabularFigures()],
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
              color: cs.onSurface.withValues(alpha: 0.06),
              strokeWidth: 1,
              dashArray: const [4, 4],
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
                  width: 16,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
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
    this.numFmtStyle = NumberFormatStyle.dotDecimal,
  });

  final List<MapEntry<String, double>> entries;
  final double total;
  final List<Color> colors;
  final AppLocalizations l10n;
  final TransactionType type;
  final bool isSubcategoryView;
  final String cSymbol;
  final NumberFormatStyle numFmtStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = context.textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        isDark ? AppColors.dividerDark : AppColors.divider;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final pct = (entry.value / total * 100).toStringAsFixed(1);
          final name = isSubcategoryView
              ? entry.key
              : TransactionCategories.localizedName(entry.key, l10n);
          final isLast = i == entries.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(color: dividerColor, width: 1),
                    ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Text(
                    name,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Gap(12),
                Text(
                  '$cSymbol${formatAmount(entry.value, numFmtStyle)}',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
