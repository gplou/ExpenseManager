import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/dashboard/widgets/summary_section.dart';
import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(body: child),
    );

void main() {
  // ── SummarySection ──────────────────────────────────────────────────────

  group('SummarySection', () {
    testWidgets('positive balance shows an upward arrow', (tester) async {
      await tester.pumpWidget(_wrap(
        SummarySection(
          summary: const TransactionsSummary(income: 200, expense: 100),
          cSymbol: r'$',
          numFmtStyle: NumberFormatStyle.dotDecimal,
          onViewCharts: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIcons.arrowUp()), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.arrowDown()), findsNothing);
    });

    testWidgets('negative balance shows a downward arrow', (tester) async {
      await tester.pumpWidget(_wrap(
        SummarySection(
          summary: const TransactionsSummary(income: 50, expense: 200),
          cSymbol: r'$',
          numFmtStyle: NumberFormatStyle.dotDecimal,
          onViewCharts: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIcons.arrowDown()), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.arrowUp()), findsNothing);
    });

    testWidgets('view charts link invokes the callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        SummarySection(
          summary: const TransactionsSummary(income: 1, expense: 1),
          cSymbol: r'$',
          numFmtStyle: NumberFormatStyle.dotDecimal,
          onViewCharts: () => taps++,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(PhosphorIcons.arrowRight()));
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
