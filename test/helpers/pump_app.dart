import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Wraps a standalone widget in `ProviderScope` + `MaterialApp` (real
/// [AppTheme] + l10n) inside a `Scaffold`. Use for components/cells that are
/// not full screens.
///
/// The real [AppTheme] registers the `AppSemanticColors` theme extension, so
/// widgets that read `context.appColors` render with production tokens. Pass
/// `theme: AppTheme.darkTheme` to exercise dark mode.
Future<void> pumpWithProviders(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  ThemeData? theme,
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        navigatorObservers: navigatorObservers,
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// Like [pumpWithProviders], but mounts [screen] directly as `home:` (for full
/// screens that already provide their own `Scaffold`).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  ThemeData? theme,
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        navigatorObservers: navigatorObservers,
        home: screen,
      ),
    ),
  );
}
