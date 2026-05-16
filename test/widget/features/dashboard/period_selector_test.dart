import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/dashboard/widgets/period_selector.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  group('PeriodChip', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(wrap(
        PeriodChip(label: 'Hoy', isSelected: false, onTap: () {}),
      ));
      expect(find.text('Hoy'), findsOneWidget);
    });

    testWidgets('isSelected=true renders correctly', (tester) async {
      await tester.pumpWidget(wrap(
        PeriodChip(label: 'Mes', isSelected: true, onTap: () {}),
      ));
      expect(find.text('Mes'), findsOneWidget);
    });

    testWidgets('tap invokes callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        PeriodChip(label: 'X', isSelected: false, onTap: () => taps++),
      ));
      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('IconChip', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(wrap(
        IconChip(icon: Icons.calendar_today, isActive: false, onTap: () {}),
      ));
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('isActive=true renders correctly', (tester) async {
      await tester.pumpWidget(wrap(
        IconChip(icon: Icons.filter_alt, isActive: true, onTap: () {}),
      ));
      expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    });

    testWidgets('tap invokes callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        IconChip(icon: Icons.star, isActive: false, onTap: () => taps++),
      ));
      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
