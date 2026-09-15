import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/widgets/app_bottom_nav.dart';
import 'package:expense_manager/features/tutorial/tutorial_keys.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      // Con el tema real: es el que da a los botones un `minimumSize` de ancho
      // infinito, que dentro de un Row revienta el layout. Montar sin él
      // dejaría pasar esa clase de fallo.
      theme: theme ?? AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(bottomNavigationBar: child),
    );

void main() {
  testWidgets('muestra las cuatro pestañas y el botón central', (tester) async {
    await tester.pumpWidget(
      _wrap(AppBottomNav(currentIndex: 0, onSelect: (_) {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Presupuestos'), findsOneWidget);
    expect(find.text('Análisis'), findsOneWidget);
    expect(find.byKey(TutorialKeys.fabKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar una pestaña reporta su índice', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      _wrap(AppBottomNav(currentIndex: 0, onSelect: taps.add)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Análisis'));
    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();

    expect(taps, [3, 1]);
  });

  testWidgets('la pestaña activa se tinta con el acento', (tester) async {
    await tester.pumpWidget(
      _wrap(AppBottomNav(currentIndex: 2, onSelect: (_) {})),
    );
    await tester.pumpAndSettle();

    final accent = AppTheme.lightTheme.colorScheme.primary;
    final active = tester.widget<Text>(find.text('Presupuestos'));
    final inactive = tester.widget<Text>(find.text('Inicio'));

    expect(active.style?.color, accent);
    expect(inactive.style?.color, isNot(accent));
  });

  testWidgets('entra en modo oscuro sin desbordes', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppBottomNav(currentIndex: 1, onSelect: (_) {}),
        theme: AppTheme.darkTheme,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
