import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/settings/app_settings_screen.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap() {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      isProProvider.overrideWithValue(true), // hide ad banner
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: const AppSettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('renders all top-level settings rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // App settings AppBar title
    expect(find.text('Ajustes de la app'), findsOneWidget);

    // Dark mode switch
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text('Modo oscuro'), findsOneWidget);

    // List of preferences
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Moneda'), findsOneWidget);
    expect(find.text('Formato de números'), findsOneWidget);
    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(find.text('Términos de servicio'), findsOneWidget);
  });

  testWidgets('default currency subtitle shows EUR Euro', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('EUR'), findsOneWidget);
    expect(find.textContaining('Euro'), findsOneWidget);
  });

  testWidgets('default number format subtitle reads "Punto decimal"',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('1,234.56'), findsOneWidget);
  });

  testWidgets('toggling dark mode switch flips the switch state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final initial = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(initial.value, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final flipped = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(flipped.value, isTrue);
  });
}
