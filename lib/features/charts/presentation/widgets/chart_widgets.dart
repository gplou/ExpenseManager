import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/providers/number_format_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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
    this.cSymbol = '€',
    this.numFmtStyle = NumberFormatStyle.dotDecimal,
  });

  final List<MapEntry<String, double>> entries;
  final double total;
  final List<Color> colors;
  final int? touchedIndex;
  final ValueChanged<int?> onTouch;
  final String cSymbol;
  final NumberFormatStyle numFmtStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? AppColors.inkDark : AppColors.ink;
    final mutedColor = isDark ? AppColors.graphiteDark : AppColors.graphite;
    final paperColor = isDark ? AppColors.paperDark : AppColors.paper;

    final hasTouch = touchedIndex != null &&
        touchedIndex! >= 0 &&
        touchedIndex! < entries.length;
    final centerValue = hasTouch ? entries[touchedIndex!].value : total;
    final centerLabel = hasTouch
        ? '${(entries[touchedIndex!].value / total * 100).toStringAsFixed(1)}%'
        : 'TOTAL';
    final centerColor = hasTouch ? colors[touchedIndex!] : mutedColor;

    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
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
              centerSpaceRadius: 78,
              startDegreeOffset: -90,
              sections: List.generate(entries.length, (i) {
                final isTouched = touchedIndex == i;
                return PieChartSectionData(
                  color: colors[i],
                  value: entries[i].value,
                  title: '',
                  radius: isTouched ? 46 : 38,
                  borderSide: isTouched
                      ? BorderSide(color: paperColor, width: 2)
                      : BorderSide.none,
                );
              }),
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
          // Centro: etiqueta + valor (refinado)
          IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey('center-$hasTouch-${touchedIndex ?? -1}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: centerColor,
                      letterSpacing: 1.4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Gap(6),
                  Text(
                    '$cSymbol${formatAmount(centerValue, numFmtStyle)}',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: inkColor,
                      letterSpacing: -0.6,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (hasTouch) ...[
                    const Gap(4),
                    SizedBox(
                      width: 110,
                      child: Text(
                        entries[touchedIndex!].key,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: mutedColor,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final tt = context.textTheme;
    final mutedColor = isDark ? AppColors.graphiteDark : AppColors.graphite;
    final softColor = isDark ? AppColors.graphiteSoftDark : AppColors.graphiteSoft;
    final trackColor = cs.onSurface.withValues(alpha: isDark ? 0.05 : 0.04);
    final gridColor = cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04);

    final rawMax = entries.isEmpty
        ? 100.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxY = rawMax * 1.2;

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
              tooltipMargin: 8,
              tooltipBorderRadius: BorderRadius.circular(8),
              tooltipBorder: BorderSide(
                color: cs.onSurface.withValues(alpha: 0.08),
                width: 1,
              ),
              getTooltipColor: (_) =>
                  isDark ? AppColors.raisedDark : AppColors.ink,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                '$cSymbol${formatAmount(rod.toY, numFmtStyle)}',
                TextStyle(
                  fontFamily: 'GeneralSans',
                  color: isDark ? AppColors.inkDark : AppColors.paper,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: -0.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
                      space: 8,
                      child: Text(
                        short,
                        style: tt.labelSmall?.copyWith(
                          fontSize: 10,
                          color: mutedColor,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  }
                  final icon = TransactionCategories.iconFor(
                      entries[i].key, type,
                      extra: extra);
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Icon(icon, size: 13, color: mutedColor),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: maxY <= 0 ? null : maxY / 4,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      '$cSymbol${formatAmount(value, numFmtStyle, decimals: 0)}',
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: softColor,
                        letterSpacing: -0.1,
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
            horizontalInterval: maxY <= 0 ? null : maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: gridColor,
              strokeWidth: 1,
              dashArray: const [3, 6],
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
                  width: 10,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: trackColor,
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDarkMode : AppColors.surface;
    final dividerColor = isDark ? AppColors.dividerDark : AppColors.divider;
    final textPrimary = isDark ? AppColors.inkDark : AppColors.ink;
    final textMuted = isDark ? AppColors.graphiteDark : AppColors.graphite;
    final textFaint =
        isDark ? AppColors.graphiteSoftDark : AppColors.graphiteSoft;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: dividerColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(entries.length, (i) {
            final entry = entries[i];
            final pct = total > 0 ? entry.value / total : 0.0;
            final pctLabel = (pct * 100).toStringAsFixed(1);
            final name = isSubcategoryView
                ? entry.key
                : TransactionCategories.localizedName(entry.key, l10n);
            final isLast = i == entries.length - 1;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Rank index — sutil, sólo para top 9
                      SizedBox(
                        width: 16,
                        child: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: textFaint,
                            letterSpacing: 0.4,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const Gap(10),
                      // Dot indicator con anillo
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors[i].withValues(alpha: 0.18),
                            width: 3,
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontFamily: 'GeneralSans',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: textPrimary,
                                      letterSpacing: -0.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$pctLabel%',
                                  style: TextStyle(
                                    fontFamily: 'GeneralSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: textMuted,
                                    letterSpacing: 0.2,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                const Gap(10),
                                Text(
                                  '$cSymbol${formatAmount(entry.value, numFmtStyle)}',
                                  style: TextStyle(
                                    fontFamily: 'GeneralSans',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                    letterSpacing: -0.2,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Gap(8),
                            LayoutBuilder(
                              builder: (_, constraints) => Stack(
                                children: [
                                  Container(
                                    height: 2,
                                    width: constraints.maxWidth,
                                    decoration: BoxDecoration(
                                      color: colors[i].withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 400),
                                    curve: Curves.easeOutCubic,
                                    height: 2,
                                    width: constraints.maxWidth * pct,
                                    decoration: BoxDecoration(
                                      color: colors[i],
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: dividerColor.withValues(alpha: 0.5),
                    indent: 54,
                    endIndent: 0,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
