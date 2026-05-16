import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/l10n/app_localizations.dart';

/// Wraps [child] in a `ProviderScope` + `MaterialApp` configured for tests:
/// - Spanish locale by default (matches default app locale).
/// - `AppLocalizations.delegate` and supported locales registered.
/// - Caller-supplied [overrides] applied to the `ProviderScope`.
///
/// Shared between widget tests that exercise screens. Caller is responsible
/// for overriding any provider that touches the network or RevenueCat — this
/// helper does NOT auto-inject fakes.
Future<void> pumpWithProviders(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('es'),
  ThemeData? theme,
  NavigatorObserver? navigatorObserver,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? ThemeData.light(),
        home: Scaffold(body: child),
        navigatorObservers:
            navigatorObserver != null ? [navigatorObserver] : const [],
      ),
    ),
  );
}

/// Same as [pumpWithProviders] but renders [child] as the full app body
/// (without an outer `Scaffold`). Use for screens that already define their
/// own `Scaffold` and `AppBar`.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Locale locale = const Locale('es'),
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? ThemeData.light(),
        home: screen,
      ),
    ),
  );
}
