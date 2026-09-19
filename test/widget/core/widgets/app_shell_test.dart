import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/widgets/ad_banner_footer.dart';
import 'package:expense_manager/core/widgets/app_bottom_nav.dart';
import 'package:expense_manager/core/widgets/app_shell.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Shell con cuatro pantallas de pega: el objetivo es la navegación y el
/// cromo, no las pantallas reales (que arrastrarían medio grafo de providers).
Widget _wrap({required bool isPro}) {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));

  final router = GoRouter(
    initialLocation: '/a',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
              routes: [GoRoute(path: '/a', builder: (_, __) => stub('A'))]),
          StatefulShellBranch(
              routes: [GoRoute(path: '/b', builder: (_, __) => stub('B'))]),
          StatefulShellBranch(
              routes: [GoRoute(path: '/c', builder: (_, __) => stub('C'))]),
          StatefulShellBranch(
              routes: [GoRoute(path: '/d', builder: (_, __) => stub('D'))]),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [isProProvider.overrideWithValue(isPro)],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('arranca en la primera rama y conmuta al tocar una pestaña',
      (tester) async {
    await tester.pumpWidget(_wrap(isPro: true));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);

    await tester.tap(find.text('Análisis'));
    await tester.pumpAndSettle();

    expect(find.text('D'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('las ramas conservan su estado al ir y volver', (tester) async {
    await tester.pumpWidget(_wrap(isPro: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Presupuestos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    // IndexedStack mantiene las cuatro montadas: 'C' sigue en el árbol aunque
    // no se pinte. Es lo que hace que volver a una pestaña no recargue.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('C', skipOffstage: false), findsOneWidget);
  });

  testWidgets('el usuario PRO no ve banner; el FREE sí', (tester) async {
    await tester.pumpWidget(_wrap(isPro: true));
    await tester.pumpAndSettle();
    expect(find.byType(AdBannerFooter), findsNothing);

    await tester.pumpWidget(_wrap(isPro: false));
    await tester.pumpAndSettle();
    expect(find.byType(AdBannerFooter), findsOneWidget);
  });

  testWidgets('la barra inferior está siempre presente', (tester) async {
    await tester.pumpWidget(_wrap(isPro: true));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsOneWidget);
  });
}
