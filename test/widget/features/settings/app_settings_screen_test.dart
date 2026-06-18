import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/settings/app_settings_screen.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/core/services/biometric_auth_service.dart';
import 'package:expense_manager/core/services/notification_service.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../../../helpers/mocks.dart';

Widget _wrap({List<Override> overrides = const []}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      isProProvider.overrideWithValue(true), // hide ad banner
      ...overrides,
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

    // Switches: dark mode + app lock + recordatorios de recurrentes
    expect(find.byType(SwitchListTile), findsNWidgets(3));
    expect(find.text('Modo oscuro'), findsOneWidget);
    expect(find.text('Bloqueo de la app'), findsOneWidget);
    expect(find.text('Recordatorios de recurrentes'), findsOneWidget);

    // List of preferences
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Moneda'), findsOneWidget);
    expect(find.text('Formato de números'), findsOneWidget);
    expect(find.text('Exportar copia de seguridad'), findsOneWidget);
    expect(find.text('Importar copia'), findsOneWidget);
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

    final darkMode = find.widgetWithText(SwitchListTile, 'Modo oscuro');
    expect(tester.widget<SwitchListTile>(darkMode).value, isFalse);

    await tester.tap(darkMode);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(darkMode).value, isTrue);
  });

  group('app lock toggle', () {
    late MockBiometricAuthService biometrics;

    setUp(() {
      biometrics = MockBiometricAuthService();
    });

    Finder appLockTile() =>
        find.widgetWithText(SwitchListTile, 'Bloqueo de la app');

    testWidgets('enables only after a successful authentication',
        (tester) async {
      when(() => biometrics.isSupported()).thenAnswer((_) async => true);
      when(() => biometrics.authenticate(any()))
          .thenAnswer((_) async => true);

      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(overrides: [
        biometricAuthServiceProvider.overrideWithValue(biometrics),
      ]));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(appLockTile()).value, isFalse);

      await tester.tap(appLockTile());
      await tester.pumpAndSettle();

      verify(() => biometrics.authenticate(any())).called(1);
      expect(tester.widget<SwitchListTile>(appLockTile()).value, isTrue);
    });

    testWidgets('stays disabled when authentication fails', (tester) async {
      when(() => biometrics.isSupported()).thenAnswer((_) async => true);
      when(() => biometrics.authenticate(any()))
          .thenAnswer((_) async => false);

      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(overrides: [
        biometricAuthServiceProvider.overrideWithValue(biometrics),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(appLockTile());
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(appLockTile()).value, isFalse);
    });

    testWidgets('shows a snackbar when the device has no screen lock',
        (tester) async {
      when(() => biometrics.isSupported()).thenAnswer((_) async => false);

      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(overrides: [
        biometricAuthServiceProvider.overrideWithValue(biometrics),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(appLockTile());
      await tester.pumpAndSettle();

      verifyNever(() => biometrics.authenticate(any()));
      expect(
        find.text('Configura primero un bloqueo de pantalla en tu dispositivo'),
        findsOneWidget,
      );
      expect(tester.widget<SwitchListTile>(appLockTile()).value, isFalse);
    });
  });

  group('recurring reminders toggle', () {
    late MockNotificationService notifications;

    setUp(() {
      notifications = MockNotificationService();
      when(() => notifications.cancelAll()).thenAnswer((_) async {});
    });

    Finder remindersTile() =>
        find.widgetWithText(SwitchListTile, 'Recordatorios de recurrentes');

    testWidgets('turns on when the permission is granted', (tester) async {
      when(() => notifications.requestPermissions())
          .thenAnswer((_) async => true);

      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
      ]));
      await tester.pumpAndSettle();

      await tester.ensureVisible(remindersTile());
      await tester.tap(remindersTile());
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(remindersTile()).value, isTrue);
    });

    testWidgets('stays off and warns when the permission is denied',
        (tester) async {
      when(() => notifications.requestPermissions())
          .thenAnswer((_) async => false);

      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
      ]));
      await tester.pumpAndSettle();

      await tester.ensureVisible(remindersTile());
      await tester.tap(remindersTile());
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(remindersTile()).value, isFalse);
      expect(
        find.textContaining('Activa las notificaciones'),
        findsOneWidget,
      );
    });
  });
}
