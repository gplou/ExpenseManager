// Recorrido completo del tutorial interactivo sobre el dispositivo real.
//
// Existe porque el fallo que cubre no se reproduce en `flutter test`: el
// spotlight se sitúa midiendo el widget objetivo en coordenadas de pantalla,
// y eso depende de la geometría real, del banner de anuncios y de la
// transición de ruta del login al dashboard. En un widget test, con la
// pantalla montada directamente y sin transición, todo cuadraba y el tutorial
// pasaba — en el dispositivo, el foco salía a media pantalla y la tarjeta con
// el botón "Siguiente" caía fuera de la vista, dejando al usuario sin forma
// de avanzar.
//
// Run with:
//   fvm flutter test integration_test/tutorial_flow_test.dart \
//     --dart-define-from-file=dart_defines.json \
//     --dart-define-from-file=dart_defines_e2e.json

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:expense_manager/features/tutorial/tutorial_notifier.dart';
import 'package:expense_manager/features/tutorial/tutorial_tooltip_card.dart';

import 'helpers/e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'el tutorial se recorre entero: cada paso muestra su tarjeta y avanza',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await bootApp(tester);
      await ensureLoggedIn(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      container.read(tutorialProvider.notifier).start();
      await settle(tester);

      var guard = 0;
      while (container.read(tutorialProvider).isActive && guard < 20) {
        final step = container.read(tutorialProvider).stepIndex;

        // Lo que de verdad se rompió: sin tarjeta en pantalla el usuario no
        // tiene ningún botón que pulsar y el tutorial es un callejón sin
        // salida (solo "Omitir").
        expect(
          find.byType(TutorialTooltipCard),
          findsOneWidget,
          reason: 'el paso $step se quedó sin tarjeta visible',
        );

        final nextButton = find.descendant(
          of: find.byType(TutorialTooltipCard),
          matching: find.byType(FilledButton),
        );
        expect(
          nextButton,
          findsOneWidget,
          reason: 'el paso $step no ofrece botón para continuar',
        );

        // `warnIfMissed: false` no: queremos que falle si el botón está
        // fuera de pantalla o tapado, que es exactamente el bug.
        await tester.tap(nextButton);
        await settle(tester);

        expect(
          !container.read(tutorialProvider).isActive ||
              container.read(tutorialProvider).stepIndex > step,
          isTrue,
          reason: 'pulsar "siguiente" en el paso $step no avanzó el tutorial',
        );
        guard++;
      }

      expect(container.read(tutorialProvider).isActive, isFalse,
          reason: 'el tutorial debería haber terminado');
      expect(tester.takeException(), isNull);
    },
  );
}
