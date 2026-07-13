// Flujo E2E principal de transacciones: crear → verificar → editar → borrar.
//
// Replica el checklist manual de release sobre la app real (backend Supabase
// real, SQLite real, usuario E2E FREE). Ver helpers/e2e_helpers.dart para
// cómo pasar las credenciales.
//
//   fvm flutter test integration_test/transactions_flow_test.dart \
//     --dart-define-from-file=dart_defines.json \
//     --dart-define-from-file=dart_defines_e2e.json \
//     -d emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:expense_manager/core/constants/test_keys.dart';
import 'package:expense_manager/core/widgets/numeric_keypad.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/tutorial/tutorial_keys.dart';

import 'helpers/e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'crea, edita y borra una transacción de gasto',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      await bootApp(tester);
      await ensureLoggedIn(tester);

      final note = 'e2e-${DateTime.now().millisecondsSinceEpoch}';
      final noteEdited = '$note-edited';
      final category = TransactionCategories.expense.first.name;

      // ── Crear ───────────────────────────────────────────────────────────
      await tester.tap(find.byKey(TutorialKeys.fabKey));
      await settle(tester);

      // Importe 73 en el keypad.
      Finder keypadDigit(String d) => find.descendant(
            of: find.byType(NumericKeypad),
            matching: find.text(d),
          );
      await waitFor(tester, keypadDigit('7'));
      await tester.tap(keypadDigit('7'));
      await tester.tap(keypadDigit('3'));
      await tester.pump();

      // Categoría: primer builtin de gasto (siempre presente en la tira
      // rápida para un usuario sin historial; chip con ValueKey(nombre)).
      await waitFor(tester, find.byKey(ValueKey(category)));
      await tester.tap(find.byKey(ValueKey(category)));
      await tester.pump();

      // Nota única para localizar el tile después.
      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, note);
      await tester.tap(find.widgetWithText(TextButton, l10nEn.save));
      await settle(tester);

      // Guardar con la tecla ✓ del keypad.
      await tester.tap(find.byKey(TestKeys.keypadSubmit));
      await settle(tester);

      // El dashboard muestra el tile con la nota.
      await waitOrScrollTo(tester, find.text(note));
      expect(find.text(note), findsOneWidget);

      // ── Editar ──────────────────────────────────────────────────────────
      await tester.tap(find.text(note));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, noteEdited);
      await tester.tap(find.widgetWithText(TextButton, l10nEn.save));
      await settle(tester);
      await tester.tap(find.byKey(TestKeys.keypadSubmit));
      await settle(tester);

      await waitOrScrollTo(tester, find.text(noteEdited));
      expect(find.text(noteEdited), findsOneWidget);
      expect(find.text(note), findsNothing);

      // ── Borrar ──────────────────────────────────────────────────────────
      await tester.tap(find.text(noteEdited));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await settle(tester);
      // Diálogo de confirmación: el botón "Delete" (el título no es botón).
      await tester.tap(find.widgetWithText(TextButton, l10nEn.delete));
      await settle(tester);

      await waitForGone(tester, find.text(noteEdited));
      expect(tester.takeException(), isNull);
    },
  );
}
