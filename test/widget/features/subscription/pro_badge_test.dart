import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/subscription/widgets/pro_badge.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('renders the PRO label', (tester) async {
    await tester.pumpWidget(wrap(const ProBadge()));
    expect(find.text('PRO'), findsOneWidget);
  });

  testWidgets('has a pill shape (rounded > 50)', (tester) async {
    await tester.pumpWidget(wrap(const ProBadge()));
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    final radius = (decoration.borderRadius as BorderRadius).topLeft.x;
    expect(radius, greaterThan(50));
  });
}
