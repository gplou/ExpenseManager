// Helpers compartidos por los flujos E2E de integration_test/.
//
// Los flujos corren contra el backend real (Supabase) con un usuario
// dedicado FREE, cuyos datos viven solo en la SQLite local del dispositivo.
// Las credenciales se inyectan por dart-define (nunca commiteadas):
//
//   fvm flutter test integration_test/transactions_flow_test.dart \
//     --dart-define-from-file=dart_defines.json \
//     --dart-define-from-file=dart_defines_e2e.json \
//     -d <device>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/constants/test_keys.dart';
import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/core/providers/locale_provider.dart'
    show kLocaleKey;
import 'package:expense_manager/features/tutorial/tutorial_keys.dart';
import 'package:expense_manager/features/tutorial/tutorial_notifier.dart'
    show kTutorialSeenKey;
import 'package:expense_manager/l10n/app_localizations_en.dart';
import 'package:expense_manager/main.dart' as app;

/// Usuario E2E dedicado (FREE). Solo existe en auth; sus datos son locales.
const e2eEmail = String.fromEnvironment('E2E_EMAIL');
const e2ePassword = String.fromEnvironment('E2E_PASSWORD');

/// Los tests fijan el locale a inglés (ver [resetLocalState]), así que los
/// textos se buscan siempre contra las cadenas EN generadas.
final l10nEn = AppLocalizationsEn();

/// Pref donde guardamos el uid del usuario E2E tras el primer login en este
/// dispositivo, para poder limpiar sus datos ANTES de arrancar la app en
/// ejecuciones posteriores (una vez cargados los providers, borrar la BD ya
/// no refresca lo que tienen en memoria).
const _kE2eUidPref = 'e2e_user_id';

/// Siembra los flags de primer arranque ANTES de arrancar la app (tutorial
/// ya visto, locale inglés) y borra los datos locales del usuario E2E de
/// ejecuciones anteriores — solo los suyos: nunca tocamos filas ni tombstones
/// de otros usuarios del dispositivo.
Future<void> seedFirstRunFlags() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kTutorialSeenKey, true);
  await prefs.setString(kLocaleKey, 'en');

  final e2eUid = prefs.getString(_kE2eUidPref);
  if (e2eUid != null) {
    await LocalDatabase.instance.clearUserData(e2eUid);
  }
}

/// Arranca la app real ([app.main]). Solo puede llamarse UNA vez por proceso
/// (Supabase.initialize no es re-entrante) — un flujo completo por archivo.
Future<void> bootApp(WidgetTester tester) async {
  await seedFirstRunFlags();

  // main() sustituye FlutterError.onError (logging + Sentry) y desconecta el
  // handler del binding de test; sin re-encadenarlo, un FlutterError de la
  // app quedaría solo logueado y el test pasaría en verde.
  final testHandler = FlutterError.onError;
  await app.main();
  final appHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    appHandler?.call(details);
    testHandler?.call(details);
  };

  await settle(tester);
}

/// pumpAndSettle tolerante: los banners de ads y otras animaciones continuas
/// nunca "asientan", así que el timeout no es un fallo.
Future<void> settle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  } on FlutterError {
    // Animación continua en pantalla; seguimos.
  }
}

/// Espera (tiempo real) a que [finder] encuentre al menos un widget.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 200));
    if (tester.any(finder)) return;
  }
  fail('Timed out (${timeout.inSeconds}s) waiting for $finder');
}

/// Espera a que [finder] deje de encontrar widgets.
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 200));
    if (!tester.any(finder)) return;
  }
  fail('Timed out (${timeout.inSeconds}s) waiting for $finder to disappear');
}

Finder _verticalScrollable() => find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );

/// Espera a que [finder] exista; si tras [waitBeforeScroll] no ha aparecido,
/// asume que está fuera del viewport y hace scroll vertical hasta verlo.
Future<void> waitOrScrollTo(
  WidgetTester tester,
  Finder finder, {
  Duration waitBeforeScroll = const Duration(seconds: 5),
}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < waitBeforeScroll) {
    await tester.pump(const Duration(milliseconds: 200));
    if (tester.any(finder)) {
      await tester.ensureVisible(finder.first);
      await settle(tester, timeout: const Duration(seconds: 3));
      return;
    }
  }
  await tester.scrollUntilVisible(
    finder.first,
    120,
    scrollable: _verticalScrollable().first,
  );
  await settle(tester, timeout: const Duration(seconds: 3));
}

/// Deja la app autenticada como el usuario E2E en el dashboard, con sus
/// datos locales limpios.
///
/// El dispositivo puede traer una sesión persistida de OTRO usuario (p. ej.
/// la cuenta de desarrollo en un emulador de trabajo): en ese caso cierra
/// sesión primero — jamás ejecutamos el flujo sobre una cuenta ajena.
Future<void> ensureLoggedIn(WidgetTester tester) async {
  final auth = Supabase.instance.client.auth;

  if (auth.currentUser != null && auth.currentUser!.email != e2eEmail) {
    await auth.signOut();
    // El router reacciona a authStateChanges y redirige al login.
  }

  final loggedInAsE2e = auth.currentUser != null;
  final sw = Stopwatch()..start();
  var loginVisible = false;
  while (sw.elapsed < const Duration(seconds: 30)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (loggedInAsE2e && tester.any(find.byKey(TutorialKeys.fabKey))) {
      await _rememberE2eUid();
      return; // sesión E2E persistida de una ejecución anterior
    }
    if (tester.any(find.byKey(TestKeys.loginEmailField))) {
      loginVisible = true;
      break;
    }
  }
  expect(loginVisible, isTrue,
      reason: 'Ni el dashboard ni el login aparecieron tras 30s');
  expect(e2eEmail.isNotEmpty && e2ePassword.isNotEmpty, isTrue,
      reason: 'Faltan E2E_EMAIL / E2E_PASSWORD: añade '
          '--dart-define-from-file=dart_defines_e2e.json (local) '
          'o los secrets de CI');

  await tester.enterText(find.byKey(TestKeys.loginEmailField), e2eEmail);
  await tester.enterText(find.byKey(TestKeys.loginPasswordField), e2ePassword);
  // Cierra el teclado para que el botón no quede tapado.
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, timeout: const Duration(seconds: 3));
  await tester.ensureVisible(find.byKey(TestKeys.loginSubmitButton));
  await tester.tap(find.byKey(TestKeys.loginSubmitButton));

  // Login real contra Supabase + redirect del router.
  await waitFor(tester, find.byKey(TutorialKeys.fabKey),
      timeout: const Duration(seconds: 45));
  await _rememberE2eUid();
  await settle(tester);
}

/// Persiste el uid del usuario E2E para que [seedFirstRunFlags] pueda limpiar
/// sus datos antes del próximo arranque.
Future<void> _rememberE2eUid() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kE2eUidPref, uid);
}
