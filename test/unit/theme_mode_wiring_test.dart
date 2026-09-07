import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/theme_provider.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/settings/app_settings_screen.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// `theme_provider_test.dart` cubre el notifier aislado; esto cubre el cableado
/// hasta `MaterialApp.themeMode`, que es donde se sospechaba un fallo: durante
/// la tanda de capturas de tienda pareció que pulsar "Modo oscuro" cambiaba el
/// provider y el interruptor pero dejaba la app en claro. No se reproduce; estos
/// tests fijan el comportamiento para que un futuro cambio no lo rompa.
///
/// Nota: los helpers de `pump_app.dart` pasan `theme:` a mano y nunca
/// `themeMode`, así que ningún otro widget test ejercita este camino.

/// Réplica del cableado de tema de `MyApp` (lib/main.dart).
class _ThemedApp extends ConsumerWidget {
  const _ThemedApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.light;
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: home,
    );
  }
}

/// Igual, pero con `MaterialApp.router` como en producción. El router se crea
/// fuera de `build` a propósito: `routerProvider` es `keepAlive` y estable, y
/// recrearlo en cada rebuild reiniciaría la navegación al cambiar de tema.
final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(body: Text('home')),
      routes: [
        GoRoute(
          path: 'settings',
          builder: (_, __) => const AppSettingsScreen(),
        ),
      ],
    ),
  ],
);

class _ThemedRouterApp extends ConsumerWidget {
  const _ThemedRouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.light;
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
    );
  }
}

Brightness _brightnessAt(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder)).brightness;

Finder get _darkModeSwitch => find.byType(SwitchListTile).first;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MaterialApp sigue a themeModeProvider', () {
    testWidgets('el toggle repinta la app tras resolverse build()',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(themeModeProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _ThemedApp(home: Scaffold(body: Text('x'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(_brightnessAt(tester, find.text('x')), Brightness.light);

      await container.read(themeModeProvider.notifier).toggle();
      await tester.pumpAndSettle();

      expect(_brightnessAt(tester, find.text('x')), Brightness.dark);
    });

    testWidgets('el toggle gana aunque build() aun este en vuelo',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: _ThemedApp(home: Scaffold(body: Text('x')))),
      );
      await tester.pump(); // build() sin resolver: state es AsyncLoading

      final container =
          ProviderScope.containerOf(tester.element(find.text('x')));
      await container.read(themeModeProvider.notifier).toggle();
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider).value, ThemeMode.dark);
      expect(_brightnessAt(tester, find.text('x')), Brightness.dark);
    });
  });

  group('interruptor de Ajustes', () {
    testWidgets('pulsarlo cambia provider, interruptor y tema', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isProProvider.overrideWith((ref) => true)],
          child: const _ThemedApp(home: AppSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final container =
          ProviderScope.containerOf(tester.element(_darkModeSwitch));
      expect(_brightnessAt(tester, _darkModeSwitch), Brightness.light);
      expect(tester.widget<SwitchListTile>(_darkModeSwitch).value, isFalse);

      await tester.tap(_darkModeSwitch);
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider).value, ThemeMode.dark);
      expect(tester.widget<SwitchListTile>(_darkModeSwitch).value, isTrue);
      expect(_brightnessAt(tester, _darkModeSwitch), Brightness.dark);
    });

    testWidgets('tambien bajo MaterialApp.router en una ruta pusheada',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isProProvider.overrideWith((ref) => true)],
          child: const _ThemedRouterApp(),
        ),
      );
      await tester.pumpAndSettle();

      final ctx = tester.element(find.text('home'));
      final container = ProviderScope.containerOf(ctx);
      unawaited(GoRouter.of(ctx).push('/settings'));
      await tester.pumpAndSettle();

      expect(_brightnessAt(tester, _darkModeSwitch), Brightness.light);

      await tester.tap(_darkModeSwitch);
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider).value, ThemeMode.dark);
      expect(tester.widget<SwitchListTile>(_darkModeSwitch).value, isTrue);
      expect(_brightnessAt(tester, _darkModeSwitch), Brightness.dark);
      // La ruta sigue en pie: el rebuild por tema no reinicia la navegación.
      expect(find.byType(AppSettingsScreen), findsOneWidget);
    });
  });
}
