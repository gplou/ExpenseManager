// ANDAMIAJE TEMPORAL — tanda de capturas para la ficha de la App Store.
//
// Punto de entrada: `bash tool/screenshots_ios.sh`.
//
// Pilota la app real en el simulador y para en cada pantalla de interés; en
// cada parada `tool/screenshots/daemon.sh` captura con `simctl` desde el host.
//
// Vive en `tool/` y NO en `integration_test/` a propósito: el workflow de CI
// lanza `flutter test integration_test` sobre la carpeta entera y este archivo
// necesita `SCREENSHOT_MODE`, el daemon del host y los datos sembrados.
//
// Cada paso está aislado en [shot]: si un finder cambia, esa captura se marca
// como fallida en el resumen final pero la tanda continúa.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/config/router.dart';
import 'package:expense_manager/core/constants/test_keys.dart';
import 'package:expense_manager/core/providers/locale_provider.dart'
    show kLocaleKey;
import 'package:expense_manager/core/providers/theme_provider.dart'
    show kThemeModeKey;
import 'package:expense_manager/features/dashboard/widgets/period_selector.dart'
    show PeriodChip;
import 'package:expense_manager/features/transactions/presentation/widgets/transaction_list_tile.dart'
    show TransactionTile;
import 'package:expense_manager/features/tutorial/tutorial_keys.dart';
import 'package:expense_manager/features/tutorial/tutorial_notifier.dart'
    show kTutorialSeenKey;
import 'package:expense_manager/l10n/app_localizations_es.dart';
import 'package:expense_manager/main.dart' as app;

const e2eEmail = String.fromEnvironment('E2E_EMAIL');
const e2ePassword = String.fromEnvironment('E2E_PASSWORD');

/// Segunda pasada: reutiliza la sesión y los datos ya sembrados y solo captura
/// las pantallas en modo oscuro.
const dark = bool.fromEnvironment('SHOT_DARK');

final l10n = AppLocalizationsEs();

late IntegrationTestWidgetsFlutterBinding binding;
final failures = <String>[];

// ── Utilidades ───────────────────────────────────────────────────────────────

Future<void> settle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  } on FlutterError {
    // Animación continua (banner de ads, shimmer); seguimos.
  }
}

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
  throw StateError('Timeout esperando $finder');
}

/// Buzón compartido con el host dentro del contenedor de datos de la app; en el
/// simulador es una carpeta normal del Mac (`simctl get_app_container … data`).
late Directory mailbox;

/// Pide al host una captura con `simctl` y espera a que confirme.
///
/// `binding.takeScreenshot` no sirve aquí: el driver de integration_test
/// entrega esos bytes al terminar el test (todas las capturas saldrían con el
/// estado final), y además la imagen que renderiza el plugin de iOS no incluye
/// la barra de estado del sistema.
Future<void> hostScreenshot(WidgetTester tester, String name) async {
  final request = File('${mailbox.path}/$name.request');
  final done = File('${mailbox.path}/$name.done');
  if (done.existsSync()) done.deleteSync();
  request.writeAsStringSync(name);

  final sw = Stopwatch()..start();
  while (sw.elapsed < const Duration(seconds: 30)) {
    // pump() real: deja correr el I/O mientras la UI se mantiene congelada.
    await tester.pump(const Duration(milliseconds: 150));
    if (done.existsSync()) {
      done.deleteSync();
      return;
    }
  }
  throw StateError('El host no confirmó la captura "$name" en 30 s');
}

/// Ejecuta [action], deja asentar la UI y captura con el nombre [name].
/// Un fallo se anota y no aborta la tanda.
Future<void> shot(
  WidgetTester tester,
  String name,
  Future<void> Function() action,
) async {
  try {
    await action();
    await settle(tester);
    // Frame extra de margen: sombras e imágenes que entran con animación.
    await tester.pump(const Duration(milliseconds: 500));
    await hostScreenshot(tester, name);
    debugPrint('✅  $name');
  } catch (e) {
    failures.add('$name → $e');
    debugPrint('❌  $name → $e');
  }
}

/// Como [shot], pero sin capturar: pasos intermedios de navegación.
Future<void> step(
  WidgetTester tester,
  String label,
  Future<void> Function() action,
) async {
  try {
    await action();
    await settle(tester);
  } catch (e) {
    failures.add('(paso) $label → $e');
    debugPrint('⚠️   paso "$label" → $e');
  }
}

/// Navegación por ruta desde el árbol vivo: no depende de textos ni de la
/// posición de los botones.
void go(WidgetTester tester, String route) {
  final ctx = tester.element(find.byType(Scaffold).last);
  GoRouter.of(ctx).go(route);
}

void push(WidgetTester tester, String route) {
  final ctx = tester.element(find.byType(Scaffold).last);
  GoRouter.of(ctx).push(route);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder.first, warnIfMissed: false);
  await settle(tester);
}

/// Cierra la ruta/sheet/diálogo superior.
Future<void> pop(WidgetTester tester) async {
  final ctx = tester.element(find.byType(Scaffold).last);
  await Navigator.of(ctx, rootNavigator: true).maybePop();
  await settle(tester);
}

Finder verticalScrollable() => find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );

/// Desplaza la lista de la pantalla actual [dy] píxeles.
///
/// Va contra la `ScrollPosition`, no con un gesto: `tester.drag` fallaba en las
/// rutas apiladas con `push` (el finder cogía el scrollable del dashboard, que
/// sigue vivo debajo) y la captura salía sin desplazar. Se elige la última
/// posición con recorrido disponible, que es la de la ruta de encima.
Future<void> scrollBy(WidgetTester tester, double dy) async {
  final scrollables = tester
      .stateList<ScrollableState>(verticalScrollable())
      .where((s) => s.position.hasContentDimensions)
      .toList();
  final target = scrollables.lastWhere(
    (s) => s.position.maxScrollExtent > 0,
    orElse: () => throw StateError('Ninguna lista con recorrido en pantalla'),
  );
  final to = (target.position.pixels + dy)
      .clamp(0.0, target.position.maxScrollExtent);
  target.position.jumpTo(to);
  await settle(tester);
}

void report() {
  if (failures.isEmpty) {
    debugPrint('\n🎉  Todas las capturas salieron bien.');
    return;
  }
  debugPrint('\n──── incidencias (${failures.length}) ────');
  for (final f in failures) {
    debugPrint('  $f');
  }
}

// ── Tanda ────────────────────────────────────────────────────────────────────

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tanda de capturas de tienda', (tester) async {
    mailbox = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/screenshots');
    if (mailbox.existsSync()) mailbox.deleteSync(recursive: true);
    mailbox.createSync(recursive: true);
    debugPrint('📬  buzón de capturas: ${mailbox.path}');

    // El tema se fija en prefs ANTES de arrancar: activarlo luego desde el
    // interruptor de Ajustes cambia el estado del provider pero MaterialApp
    // se queda en claro, así que las capturas oscuras salían en claro. La
    // pasada oscura es una segunda ejecución con SHOT_DARK=true.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLocaleKey, 'es');
    await prefs.setString(kThemeModeKey, dark ? 'dark' : 'light');
    await prefs.setBool(kTutorialSeenKey, dark);

    await app.main();
    await settle(tester, timeout: const Duration(seconds: 20));

    final auth = Supabase.instance.client.auth;
    if (auth.currentUser != null && auth.currentUser!.email != e2eEmail) {
      await auth.signOut();
      await settle(tester);
    }

    // ── 01-02 · Autenticación ───────────────────────────────────────────────
    // `flutter drive` reinstala la app en cada pasada y la sesión no sobrevive,
    // así que la pasada oscura también pasa por el login (sin capturarlo).
    if (tester.any(find.byKey(TestKeys.loginEmailField))) {
      if (!dark) {
        await shot(tester, '01-login', () async {});
        await shot(tester, '02-registro', () async {
          go(tester, AppRoutes.register);
        });
        await step(tester, 'volver al login', () async {
          go(tester, AppRoutes.login);
        });
      }

      await tester.enterText(find.byKey(TestKeys.loginEmailField), e2eEmail);
      await tester.enterText(
          find.byKey(TestKeys.loginPasswordField), e2ePassword);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, timeout: const Duration(seconds: 3));
      await tester.ensureVisible(find.byKey(TestKeys.loginSubmitButton));
      await tester.tap(find.byKey(TestKeys.loginSubmitButton));
    }

    await waitFor(tester, find.byKey(TutorialKeys.fabKey),
        timeout: const Duration(seconds: 60));
    await settle(tester);

    // La siembra corre en paralelo al primer render; hay que darle margen
    // ANTES de buscar el diálogo del tutorial (aparece tras el primer frame).
    await tester.pump(const Duration(seconds: 3));
    await settle(tester, timeout: const Duration(seconds: 20));

    // ── Pasada oscura: solo las tres pantallas en modo oscuro ───────────────
    if (dark) {
      await shot(tester, '25-oscuro-dashboard', () async {
        go(tester, AppRoutes.dashboard);
      });
      await shot(tester, '26-oscuro-graficos', () async {
        go(tester, AppRoutes.charts);
      });
      await shot(tester, '27-oscuro-ajustes', () async {
        go(tester, AppRoutes.dashboard);
        await settle(tester);
        push(tester, AppRoutes.appSettings);
      });
      report();
      return;
    }

    // ── 28 · Invitación al tutorial ─────────────────────────────────────────
    await waitFor(tester, find.text(l10n.tutorialDialogTitle),
        timeout: const Duration(seconds: 15));
    await shot(tester, '28-tutorial-invitacion', () async {});
    await step(tester, 'cerrar invitación', () async {
      await tap(tester, find.text(l10n.tutorialDialogLaterCta));
    });

    // ── 03-06 · Dashboard ───────────────────────────────────────────────────
    await shot(tester, '03-dashboard-mes', () async {
      go(tester, AppRoutes.dashboard);
    });
    await shot(tester, '04-dashboard-semana', () async {
      await tap(tester, find.widgetWithText(PeriodChip, l10n.periodWeek));
    });
    await shot(tester, '05-dashboard-anual', () async {
      await tap(tester, find.widgetWithText(PeriodChip, l10n.periodYear));
    });
    await step(tester, 'volver a mes', () async {
      await tap(tester, find.widgetWithText(PeriodChip, l10n.periodMonth));
    });
    // El dashboard entra casi entero en 6,9": no hay una segunda captura
    // "recientes" como en Android, saldría igual que la 03.
    await shot(tester, '06-rango-personalizado', () async {
      await tap(tester, find.byIcon(Icons.calendar_month_outlined));
    });
    await step(tester, 'cerrar selector', () async => pop(tester));

    // ── 07-11 · Gráficos ────────────────────────────────────────────────────
    await shot(tester, '07-graficos-tarta-gastos', () async {
      go(tester, AppRoutes.charts);
    });
    await shot(tester, '08-graficos-desglose', () async {
      await scrollBy(tester, 480);
    });
    await step(tester, 'volver arriba (gráficos)', () async {
      await scrollBy(tester, -480);
    });
    await shot(tester, '09-graficos-barras', () async {
      await tap(tester, find.byIcon(Icons.bar_chart_rounded));
    });
    await step(tester, 'volver a tarta', () async {
      await tap(tester, find.byIcon(Icons.pie_chart_rounded));
    });
    await shot(tester, '10-graficos-ingresos', () async {
      await tap(tester, find.text(l10n.typeIncome));
    });
    await step(tester, 'volver a gastos', () async {
      await tap(tester, find.text(l10n.typeExpense));
    });
    await shot(tester, '11-graficos-anual', () async {
      await tap(tester, find.byIcon(Icons.calendar_today_rounded));
      await tap(tester, find.text(l10n.periodYear).last);
    });
    // El periodo lo comparten dashboard y gráficos (`selectedPeriodProvider`):
    // sin restaurarlo, todo lo que viene después sale en vista anual.
    await step(tester, 'restaurar periodo mensual', () async {
      await tap(tester, find.byIcon(Icons.calendar_today_rounded));
      await tap(tester, find.text(l10n.periodMonth).last);
    });

    // ── 12-13 · Presupuestos ────────────────────────────────────────────────
    await shot(tester, '12-presupuestos', () async {
      go(tester, AppRoutes.budgets);
    });
    await shot(tester, '13-presupuesto-nuevo', () async {
      await tap(tester, find.byType(FloatingActionButton));
    });
    await step(tester, 'cerrar alta presupuesto', () async => pop(tester));

    // ── 14-16 · Historial ───────────────────────────────────────────────────
    await shot(tester, '14-historial', () async {
      go(tester, AppRoutes.transactions);
    });
    await shot(tester, '15-historial-filtros', () async {
      await tap(tester, find.byIcon(Icons.filter_list_rounded));
    });
    await step(tester, 'cerrar filtros', () async => pop(tester));
    await shot(tester, '16-historial-busqueda', () async {
      await tap(tester, find.byIcon(Icons.search_rounded));
      await tester.enterText(find.byType(TextField).first, 'super');
      await settle(tester);
      // Sin cerrar el teclado, tapa los resultados y la captura no enseña nada.
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
    });
    await step(tester, 'salir de búsqueda', () async {
      await tap(tester, find.byIcon(Icons.arrow_back_rounded));
    });

    // ── 17-18 · Alta / edición de transacción ───────────────────────────────
    await shot(tester, '17-nueva-transaccion', () async {
      go(tester, AppRoutes.addTransaction);
    });
    await step(tester, 'volver al historial', () async {
      go(tester, AppRoutes.transactions);
    });
    await shot(tester, '18-editar-transaccion', () async {
      await tap(tester, find.byType(TransactionTile));
    });
    await step(tester, 'cerrar edición', () async => pop(tester));

    // ── 19 · Chat de IA ─────────────────────────────────────────────────────
    await shot(tester, '19-chat-ia', () async {
      go(tester, AppRoutes.chat);
    });

    // ── 20 · Menú lateral ───────────────────────────────────────────────────
    await step(tester, 'volver al dashboard', () async {
      go(tester, AppRoutes.dashboard);
    });
    await shot(tester, '20-menu', () async {
      await tap(tester, find.byKey(TutorialKeys.drawerBtnKey));
    });
    await step(tester, 'cerrar menú', () async => pop(tester));

    // ── 21-23 · Ajustes ─────────────────────────────────────────────────────
    // La pantalla de ajustes entra entera en 6,9": no hay nada que desplazar
    // (en el móvil Android hacían falta dos capturas).
    await shot(tester, '21-ajustes', () async {
      push(tester, AppRoutes.appSettings);
    });
    await shot(tester, '22-idioma', () async {
      await tap(tester, find.text(l10n.language));
    });
    await step(tester, 'cerrar idioma', () async => pop(tester));
    await shot(tester, '23-moneda', () async {
      await tap(tester, find.text(l10n.currency));
    });
    await step(tester, 'cerrar moneda', () async => pop(tester));

    // ── 24 · Paywall PRO ────────────────────────────────────────────────────
    // Solo la pantalla de arriba: los precios los sirve RevenueCat y en el
    // simulador no hay StoreKit, así que abajo solo hay botones vacíos.
    await shot(tester, '24-plan-pro', () async {
      push(tester, AppRoutes.pro);
    });
    await step(tester, 'cerrar paywall', () async {
      go(tester, AppRoutes.dashboard);
    });

    // ── 29-34 · Tutorial interactivo ────────────────────────────────────────
    await step(tester, 'abrir menú para el tutorial', () async {
      await tap(tester, find.byKey(TutorialKeys.drawerBtnKey));
    });
    await step(tester, 'lanzar tutorial', () async {
      await tap(tester, find.text(l10n.tutorialTitle));
    });
    for (var i = 1; i <= 6; i++) {
      await shot(tester, '${28 + i}-tutorial-$i', () async {
        if (i > 1) {
          await tap(tester, find.text(l10n.tutorialNext));
        }
      });
    }

    report();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
