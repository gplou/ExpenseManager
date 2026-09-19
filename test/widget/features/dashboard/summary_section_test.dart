import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/dashboard/widgets/summary_section.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      // Con el tema real: es donde viven la escala tipográfica y los mínimos
      // de botón que hacen que esto se parezca a la app.
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(body: child),
    );

void main() {
  // ── SummarySection ──────────────────────────────────────────────────────

  Widget hero({
    required TransactionsSummary summary,
    String periodLabel = 'septiembre',
    int daysElapsed = 10,
    VoidCallback? onViewCharts,
  }) =>
      SummarySection(
        summary: summary,
        cSymbol: r'$',
        numFmtStyle: NumberFormatStyle.dotDecimal,
        periodLabel: periodLabel,
        daysElapsed: daysElapsed,
        onViewCharts: onViewCharts ?? () {},
      );

  group('SummarySection', () {
    testWidgets('el número grande es el gasto del periodo, no el balance',
        (tester) async {
      await tester.pumpWidget(_wrap(
        hero(summary: const TransactionsSummary(income: 200, expense: 120)),
      ));
      await tester.pumpAndSettle();

      expect(find.text(r'$120.00'), findsOneWidget);
    });

    testWidgets('el eyebrow nombra el periodo activo', (tester) async {
      await tester.pumpWidget(_wrap(
        hero(
          summary: const TransactionsSummary(income: 0, expense: 0),
          periodLabel: 'septiembre',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('GASTADO EN SEPTIEMBRE'), findsOneWidget);
    });

    testWidgets('la media diaria divide el gasto entre los días transcurridos',
        (tester) async {
      await tester.pumpWidget(_wrap(
        hero(
          summary: const TransactionsSummary(income: 0, expense: 100),
          daysElapsed: 4,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(r'$25.00'), findsOneWidget);
    });

    testWidgets('el primer día no divide por cero', (tester) async {
      await tester.pumpWidget(_wrap(
        hero(
          summary: const TransactionsSummary(income: 0, expense: 30),
          daysElapsed: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Gasto y media coinciden: 30 aparece dos veces, sin NaN ni infinito.
      expect(find.text(r'$30.00'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('view charts link invokes the callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        hero(
          summary: const TransactionsSummary(income: 1, expense: 1),
          onViewCharts: () => taps++,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(PhosphorIcons.arrowRight));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });


  // ── AnimatedAmount ──────────────────────────────────────────────────────

  group('AnimatedAmount', () {
    testWidgets('renders initial value', (tester) async {
      await tester.pumpWidget(_wrap(
        AnimatedAmount(
          value: 42.5,
          formatter: (v) => v.toStringAsFixed(2),
          style: const TextStyle(),
        ),
      ));
      expect(find.text('42.50'), findsOneWidget);
    });

    testWidgets('animates between values when value changes', (tester) async {
      const key = ValueKey('amount');
      await tester.pumpWidget(_wrap(
        AnimatedAmount(
          key: key,
          value: 0,
          formatter: (v) => v.toStringAsFixed(0),
          style: const TextStyle(),
        ),
      ));
      expect(find.text('0'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        AnimatedAmount(
          key: key,
          value: 100,
          formatter: (v) => v.toStringAsFixed(0),
          style: const TextStyle(),
        ),
      ));
      // mid-tween: should not yet display the final value
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('100'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('100'), findsOneWidget);
    });
  });

  // ── SummaryShimmer ──────────────────────────────────────────────────────

  group('SummaryShimmer', () {
    testWidgets('renders without exceptions', (tester) async {
      await tester.pumpWidget(_wrap(const SummaryShimmer()));
      await tester.pump(); // shimmer animates indefinitely; one frame is enough
      expect(tester.takeException(), isNull);
    });
  });
}
