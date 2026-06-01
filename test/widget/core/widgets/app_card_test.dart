import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/widgets/app_card.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('AppCard', () {
    testWidgets('renders child', (tester) async {
      await pumpWithProviders(tester, const AppCard(child: Text('hello')));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('outlined variant has no Material tap wrapper when onTap null',
        (tester) async {
      await pumpWithProviders(tester, const AppCard(child: Text('x')));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('renders InkWell when onTap provided', (tester) async {
      var tapped = false;
      await pumpWithProviders(
        tester,
        AppCard(onTap: () => tapped = true, child: const Text('tap')),
      );
      await tester.tap(find.text('tap'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('disabled InkWell is not tappable', (tester) async {
      var tapped = false;
      await pumpWithProviders(
        tester,
        AppCard(
          onTap: () => tapped = true,
          disabled: true,
          child: const Text('disabled'),
        ),
      );
      await tester.tap(find.text('disabled'));
      await tester.pumpAndSettle();
      expect(tapped, isFalse);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('filled variant renders without onTap', (tester) async {
      await pumpWithProviders(
        tester,
        const AppCard(
          variant: AppCardVariant.filled,
          child: Text('f'),
        ),
      );
      expect(find.text('f'), findsOneWidget);
    });

    testWidgets('elevated variant renders without onTap', (tester) async {
      await pumpWithProviders(
        tester,
        const AppCard(
          variant: AppCardVariant.elevated,
          child: Text('e'),
        ),
      );
      expect(find.text('e'), findsOneWidget);
    });

    testWidgets('selected outlined variant renders', (tester) async {
      await pumpWithProviders(
        tester,
        const AppCard(selected: true, child: Text('s')),
      );
      expect(find.text('s'), findsOneWidget);
    });

    testWidgets('selected elevated variant renders', (tester) async {
      await pumpWithProviders(
        tester,
        const AppCard(
          variant: AppCardVariant.elevated,
          selected: true,
          child: Text('s'),
        ),
      );
      expect(find.text('s'), findsOneWidget);
    });

    testWidgets('disabled card renders without onTap', (tester) async {
      await pumpWithProviders(
        tester,
        const AppCard(disabled: true, child: Text('d')),
      );
      expect(find.text('d'), findsOneWidget);
    });

    testWidgets('honors semanticLabel and semanticButton', (tester) async {
      await pumpWithProviders(
        tester,
        const AppCard(
          semanticLabel: 'My card',
          semanticButton: true,
          child: Text('x'),
        ),
      );
      // Widget-tree check: Semantics(label: 'My card', button: true) present.
      final found = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any((s) =>
              s.properties.label == 'My card' && s.properties.button == true);
      expect(found, isTrue);
    });

    testWidgets('custom accent and accentLight applied', (tester) async {
      await pumpWithProviders(
        tester,
        const AppCard(
          accent: Colors.red,
          accentLight: Color(0x33FF0000),
          child: Text('red'),
        ),
      );
      expect(find.text('red'), findsOneWidget);
    });

    testWidgets('respects dark theme', (tester) async {
      await pumpWithProviders(
        tester,
        const AppCard(child: Text('dark')),
        theme: AppTheme.darkTheme,
      );
      expect(find.text('dark'), findsOneWidget);
    });
  });

  group('AppCompactRow', () {
    testWidgets('renders label and chevron', (tester) async {
      await pumpWithProviders(
        tester,
        AppCompactRow(
          label: 'Category',
          hasValue: false,
          onTap: () {},
        ),
      );
      expect(find.text('Category'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('renders emoji when provided', (tester) async {
      await pumpWithProviders(
        tester,
        AppCompactRow(
          emoji: '🍕',
          label: 'Food',
          hasValue: true,
          onTap: () {},
        ),
      );
      expect(find.text('🍕'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await pumpWithProviders(
        tester,
        AppCompactRow(
          icon: Icons.star,
          label: 'Starred',
          hasValue: true,
          onTap: () {},
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('hasValue=true applies accent', (tester) async {
      await pumpWithProviders(
        tester,
        AppCompactRow(
          label: 'Picked',
          hasValue: true,
          onTap: () {},
          accent: Colors.purple,
        ),
      );
      expect(find.text('Picked'), findsOneWidget);
    });

    testWidgets('tap invokes onTap when not disabled', (tester) async {
      var tapped = false;
      await pumpWithProviders(
        tester,
        AppCompactRow(
          label: 't',
          hasValue: false,
          onTap: () => tapped = true,
        ),
      );
      await tester.tap(find.text('t'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('disabled row is not tappable', (tester) async {
      var tapped = false;
      await pumpWithProviders(
        tester,
        AppCompactRow(
          label: 'x',
          hasValue: false,
          disabled: true,
          onTap: () => tapped = true,
        ),
      );
      await tester.tap(find.text('x'));
      await tester.pumpAndSettle();
      expect(tapped, isFalse);
    });

    testWidgets('renders without emoji nor icon', (tester) async {
      await pumpWithProviders(
        tester,
        AppCompactRow(
          label: 'plain',
          hasValue: false,
          onTap: () {},
        ),
      );
      expect(find.text('plain'), findsOneWidget);
    });
  });
}
