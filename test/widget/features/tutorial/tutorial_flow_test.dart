import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/dashboard/dashboard_screen.dart';
import 'package:expense_manager/features/tutorial/tutorial_notifier.dart';
import 'package:expense_manager/features/tutorial/tutorial_tooltip_card.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../../../helpers/dashboard_overrides.dart';

// Recorrido del tutorial sobre el dashboard real.
//
// Los tests de `tutorial_overlay_test.dart` solo ejercitan el notifier, que
// siempre avanza. Lo que se rompe en la app es el overlay: si no consigue
// medir el widget de un paso, o si la tarjeta no llega a dibujarse, el
// usuario se queda sin botón que pulsar. Estos tests montan la pantalla
// entera para cubrir justo eso.

/// Monta con el **tema real** de la app, no con el de Flutter por defecto.
///
/// No es un detalle: el tema define `minimumSize` de ancho infinito para los
/// botones (pensado para los CTA a ancho completo de las hojas), y eso hace
/// estallar el layout de cualquier botón metido en un `Row`. Con el tema por
/// defecto ese fallo no aparece, y el test pasaba mientras la app se rompía
/// en el dispositivo.
Widget _wrap(List<Override> overrides, {ThemeData? theme}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: const DashboardScreen(),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'interactive_tutorial_seen_v1': true,
    });
  });

  testWidgets('cada paso del tutorial muestra su tarjeta y avanza al siguiente',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2424);
    tester.view.devicePixelRatio = 2.625;
    tester.view.padding = const FakeViewPadding(top: 63, bottom: 63);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(dashboardOverrides(isPro: false)));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    container.read(tutorialProvider.notifier).start();
    await tester.pumpAndSettle();

    // Paso 0: la tarjeta debe estar en pantalla con su botón.
    expect(find.byType(TutorialTooltipCard), findsOneWidget,
        reason: 'el paso 0 debe mostrar la tarjeta');

    var guard = 0;
    while (container.read(tutorialProvider).isActive && guard < 20) {
      final step = container.read(tutorialProvider).stepIndex;

      expect(
        find.byType(TutorialTooltipCard),
        findsOneWidget,
        reason: 'el paso $step se quedó sin tarjeta: el usuario no tiene '
            'ningún botón que pulsar para continuar',
      );

      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      final after = container.read(tutorialProvider).stepIndex;
      final stillActive = container.read(tutorialProvider).isActive;
      expect(
        !stillActive || after > step,
        isTrue,
        reason: 'pulsar "siguiente" en el paso $step no avanzó el tutorial',
      );
      guard++;
    }

    expect(container.read(tutorialProvider).isActive, isFalse,
        reason: 'el tutorial debe terminar tras recorrer todos los pasos');
  });

  testWidgets(
      'un paso cuyo objetivo aparece tarde acaba mostrando su tarjeta igualmente',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2424);
    tester.view.devicePixelRatio = 2.625;
    tester.view.padding = const FakeViewPadding(top: 63, bottom: 63);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(dashboardOverrides(isPro: false)));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );

    // Arranca directamente en el paso 1 (tarjeta de balance), que es el que
    // depende de que `summaryAsync` ya tenga datos.
    container.read(tutorialProvider.notifier).start();
    container.read(tutorialProvider.notifier).next();
    await tester.pumpAndSettle();

    expect(container.read(tutorialProvider).stepIndex, 1);
    expect(find.byType(TutorialTooltipCard), findsOneWidget);
  });
}
