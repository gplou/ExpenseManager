import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/charts/presentation/widgets/chart_widgets.dart';

enum ChartMode { pie, bar }

class ChartArea extends StatelessWidget {
  const ChartArea({super.key, 
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
  final ChartMode mode;
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
                child: mode == ChartMode.pie
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
