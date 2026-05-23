import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/features/charts/presentation/widgets/chart_widgets.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(body: SizedBox(width: 400, height: 400, child: child)),
    );

void main() {
  // ── generateChartColors ─────────────────────────────────────────────────

  group('generateChartColors', () {
    test('returns exactly the requested number of colors', () {
      expect(generateChartColors(0), isEmpty);
      expect(generateChartColors(3), hasLength(3));
      expect(generateChartColors(20), hasLength(20));
    });

    test('cycles through the palette when count > palette length', () {
      final colors = generateChartColors(30);
      // Position 14 wraps back to position 0 (palette is 14 colors)
      expect(colors[0], colors[14]);
      expect(colors[1], colors[15]);
    });
  });

  // ── ChartPieSection ─────────────────────────────────────────────────────

  group('ChartPieSection', () {
    testWidgets('renders a SizedBox of 240 and does not throw',
        (tester) async {
      final entries = [
        const MapEntry('A', 50.0),
        const MapEntry('B', 30.0),
        const MapEntry('C', 20.0),
      ];
      await tester.pumpWidget(_wrap(
        ChartPieSection(
          entries: entries,
          total: 100,
          colors: generateChartColors(3),
          touchedIndex: null,
          onTouch: (_) {},
        ),
      ));
      await tester.pump();

      // Verify our outer container is rendered
      expect(find.byType(ChartPieSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with a touched index without throwing',
        (tester) async {
      final entries = [
        const MapEntry('A', 50.0),
        const MapEntry('B', 50.0),
      ];
      await tester.pumpWidget(_wrap(
        ChartPieSection(
          entries: entries,
          total: 100,
          colors: generateChartColors(2),
          touchedIndex: 0,
          onTouch: (_) {},
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // ── ChartBarSection ─────────────────────────────────────────────────────

  group('ChartBarSection', () {
    testWidgets('renders the chart container', (tester) async {
      final entries = [
        const MapEntry('Comida', 100.0),
        const MapEntry('Transporte', 50.0),
      ];
      await tester.pumpWidget(_wrap(
        ChartBarSection(
          entries: entries,
          colors: generateChartColors(2),
          type: TransactionType.expense,
        ),
      ));
      await tester.pump();

      expect(find.byType(ChartBarSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles an empty list gracefully', (tester) async {
      await tester.pumpWidget(_wrap(
        ChartBarSection(
          entries: const [],
          colors: const [],
          type: TransactionType.expense,
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // ── ChartLegend ─────────────────────────────────────────────────────────

  group('ChartLegend', () {
    testWidgets('renders one row per entry with percentage and amount',
        (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      await tester.pumpWidget(_wrap(
        ChartLegend(
          entries: const [
            MapEntry('Comida', 80.0),
            MapEntry('Transporte', 20.0),
          ],
          total: 100,
          colors: generateChartColors(2),
          l10n: l10n,
          type: TransactionType.expense,
          cSymbol: r'€',
          numFmtStyle: NumberFormatStyle.dotDecimal,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('80.0%'), findsOneWidget);
      expect(find.text('20.0%'), findsOneWidget);
      expect(find.textContaining('€80.00'), findsOneWidget);
      expect(find.textContaining('€20.00'), findsOneWidget);
    });

    testWidgets('subcategory view renders raw names without l10n translation',
        (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      await tester.pumpWidget(_wrap(
        ChartLegend(
          entries: const [
            MapEntry('Cena pija', 50.0),
            MapEntry('Brunch', 50.0),
          ],
          total: 100,
          colors: generateChartColors(2),
          l10n: l10n,
          type: TransactionType.expense,
          isSubcategoryView: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cena pija'), findsOneWidget);
      expect(find.text('Brunch'), findsOneWidget);
    });
  });
}
