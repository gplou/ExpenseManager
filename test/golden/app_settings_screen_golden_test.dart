@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/settings/app_settings_screen.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Golden coverage for the Nocturne restyle. Baselines were generated on
/// macOS with the bundled Inter font — see test/README.md for why these are
/// excluded from the default `flutter test` run in CI.
void main() {
  Future<void> pumpSettings(WidgetTester tester, ThemeData theme) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isProProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: const AppSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Settings — light', (tester) async {
    await pumpSettings(tester, AppTheme.lightTheme);
    await expectLater(
      find.byType(AppSettingsScreen),
      matchesGoldenFile('goldens/app_settings_light.png'),
    );
  });

  testWidgets('Settings — dark', (tester) async {
    await pumpSettings(tester, AppTheme.darkTheme);
    await expectLater(
      find.byType(AppSettingsScreen),
      matchesGoldenFile('goldens/app_settings_dark.png'),
    );
  });
}
