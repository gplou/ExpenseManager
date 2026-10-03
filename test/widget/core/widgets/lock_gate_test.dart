import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/app_lock_provider.dart';
import 'package:expense_manager/core/services/biometric_auth_service.dart';
import 'package:expense_manager/core/services/external_activity_guard.dart';
import 'package:expense_manager/core/widgets/lock_gate.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/pump_app.dart';

class _FakeAppLock extends AppLockNotifier {
  _FakeAppLock(this._enabled);
  final bool _enabled;

  @override
  Future<bool> build() async => _enabled;
}

void main() {
  late MockBiometricAuthService biometrics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    biometrics = MockBiometricAuthService();
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    required bool lockEnabled,
  }) {
    // SizedBox.expand: en producción el child es el Navigator a pantalla
    // completa; el Stack del overlay toma el tamaño del child.
    return pumpWithProviders(
      tester,
      const LockGate(
        child: SizedBox.expand(
          child: Center(child: Text('contenido sensible')),
        ),
      ),
      overrides: [
        appLockProvider.overrideWith(() => _FakeAppLock(lockEnabled)),
        biometricAuthServiceProvider.overrideWithValue(biometrics),
      ],
    );
  }

  testWidgets('with app lock disabled the child is visible and no prompt runs',
      (tester) async {
    await pumpGate(tester, lockEnabled: false);
    await tester.pumpAndSettle();

    expect(find.text('contenido sensible'), findsOneWidget);
    expect(find.text('Desbloquear'), findsNothing);
    verifyNever(() => biometrics.authenticate(any()));
  });

  testWidgets('locks on launch and keeps the overlay when auth fails',
      (tester) async {
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => false);

    await pumpGate(tester, lockEnabled: true);
    await tester.pumpAndSettle();

    // Overlay visible con el botón de desbloqueo; se lanzó el prompt una vez.
    expect(find.text('Desbloquear'), findsOneWidget);
    verify(() => biometrics.authenticate(any())).called(1);
  });

  testWidgets('unlock button retries auth and removes the overlay on success',
      (tester) async {
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => false);

    await pumpGate(tester, lockEnabled: true);
    await tester.pumpAndSettle();
    expect(find.text('Desbloquear'), findsOneWidget);

    when(() => biometrics.authenticate(any())).thenAnswer((_) async => true);
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    expect(find.text('Desbloquear'), findsNothing);
    expect(find.text('contenido sensible'), findsOneWidget);
  });

  testWidgets('re-locks when the app is paused and auth is required on resume',
      (tester) async {
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => true);

    await pumpGate(tester, lockEnabled: true);
    await tester.pumpAndSettle();
    expect(find.text('Desbloquear'), findsNothing);

    // Background: bloquea internamente. (No se puede asertar el overlay aquí:
    // el binding de test desactiva los frames mientras el estado es paused.)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    // Resume con auth fallida → el overlay queda visible.
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Desbloquear'), findsOneWidget);
    // launch + resume.
    verify(() => biometrics.authenticate(any())).called(2);

    // Reintento manual con auth OK → se desbloquea.
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => true);
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.text('Desbloquear'), findsNothing);
    expect(find.text('contenido sensible'), findsOneWidget);
  });

  group('external activity (file picker, camera, share…)', () {
    final pausedAt = DateTime(2026, 9, 26, 12);

    Future<void> pauseDuringExternalActivity(
      WidgetTester tester, {
      required DateTime resumeAt,
    }) async {
      final picker = Completer<void>();
      final pick = ExternalActivityGuard.run(() => picker.future);

      withClock(Clock.fixed(pausedAt), () {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      });
      withClock(Clock.fixed(resumeAt), () {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });
      picker.complete();
      await pick;
      await tester.pumpAndSettle();
    }

    testWidgets('does not re-lock when the app comes back in time',
        (tester) async {
      when(() => biometrics.authenticate(any())).thenAnswer((_) async => true);
      await pumpGate(tester, lockEnabled: true);
      await tester.pumpAndSettle();

      await pauseDuringExternalActivity(
        tester,
        resumeAt: pausedAt.add(const Duration(minutes: 1)),
      );

      expect(find.text('Desbloquear'), findsNothing);
      expect(find.text('contenido sensible'), findsOneWidget);
      // Solo el prompt del arranque.
      verify(() => biometrics.authenticate(any())).called(1);
    });

    testWidgets('re-locks when the app comes back after maxDuration',
        (tester) async {
      when(() => biometrics.authenticate(any())).thenAnswer((_) async => true);
      await pumpGate(tester, lockEnabled: true);
      await tester.pumpAndSettle();

      when(() => biometrics.authenticate(any())).thenAnswer((_) async => false);
      await pauseDuringExternalActivity(
        tester,
        resumeAt: pausedAt
            .add(ExternalActivityGuard.maxDuration)
            .add(const Duration(seconds: 1)),
      );

      expect(find.text('Desbloquear'), findsOneWidget);
      // launch + resume.
      verify(() => biometrics.authenticate(any())).called(2);
    });
  });
}
