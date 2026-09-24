@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/dashboard/dashboard_screen.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../helpers/clock_helper.dart';
import '../helpers/dashboard_overrides.dart';

/// Golden coverage for the Nocturne restyle. Baselines were generated on
/// macOS with the bundled Inter font — see test/README.md for why these are
/// excluded from the default `flutter test` run in CI.
void main() {
  // The header renders today's date and month name, so pin the clock or the
  // baseline stops matching the day after it was generated.
  final fixedNow = DateTime(2026, 9, 15);

  UserModel user() => UserModel(
        id: 'golden-user',
        email: 'golden@example.com',
        name: 'Guillermo',
        isEmailVerified: true,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<void> pumpDashboard(WidgetTester tester, ThemeData theme) async {
    SharedPreferences.setMockInitialValues({
      'interactive_tutorial_seen_v1': true,
    });
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: dashboardOverrides(user: user()),
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expectGolden(
    WidgetTester tester,
    ThemeData theme,
    String goldenPath,
  ) {
    return withFixedClockAsync(fixedNow, () async {
      await pumpDashboard(tester, theme);
      await expectLater(
        find.byType(DashboardScreen),
        matchesGoldenFile(goldenPath),
      );
    });
  }

  testWidgets('Dashboard — light', (tester) async {
    await expectGolden(
        tester, AppTheme.lightTheme, 'goldens/dashboard_light.png');
  });

  testWidgets('Dashboard — dark', (tester) async {
    await expectGolden(
        tester, AppTheme.darkTheme, 'goldens/dashboard_dark.png');
  });
}
