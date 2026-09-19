@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/core/widgets/app_shell.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Cromo de navegación: barra inferior de cuatro pestañas con el botón de
/// alta en el centro. Las pantallas van de pega a propósito — lo que se
/// vigila aquí es la barra, no su contenido.

void main() {
  Future<void> pumpShell(WidgetTester tester, ThemeData theme) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget stub(String label) => Scaffold(body: Center(child: Text(label)));

    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
                routes: [GoRoute(path: '/a', builder: (_, __) => stub(''))]),
            StatefulShellBranch(
                routes: [GoRoute(path: '/b', builder: (_, __) => stub(''))]),
            StatefulShellBranch(
                routes: [GoRoute(path: '/c', builder: (_, __) => stub(''))]),
            StatefulShellBranch(
                routes: [GoRoute(path: '/d', builder: (_, __) => stub(''))]),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [isProProvider.overrideWithValue(true)],
        child: MaterialApp.router(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AppShell — light', (tester) async {
    await pumpShell(tester, AppTheme.lightTheme);
    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('goldens/app_shell_light.png'),
    );
  });

  testWidgets('AppShell — dark', (tester) async {
    await pumpShell(tester, AppTheme.darkTheme);
    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('goldens/app_shell_dark.png'),
    );
  });
}
