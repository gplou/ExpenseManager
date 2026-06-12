import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/app_lock_provider.dart';
import 'package:expense_manager/core/services/biometric_auth_service.dart';
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
}
