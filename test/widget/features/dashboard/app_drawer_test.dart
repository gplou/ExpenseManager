import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/auth/data/auth_repository.dart';
import 'package:expense_manager/features/auth/domain/auth_repository_contract.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';

import '../../../helpers/mocks.dart';
import 'package:expense_manager/features/dashboard/widgets/app_drawer.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

UserModel _alice() => UserModel(
      id: 'alice',
      email: 'alice@example.com',
      name: 'Alice Doe',
      isEmailVerified: true,
      createdAt: DateTime(2026),
    );

class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  _FakeSubscriptionNotifier(this._state);
  final SubscriptionState _state;
  @override
  Future<SubscriptionState> build() async => _state;
}

Widget _wrap({
  UserModel? user,
  bool isEmailPassword = true,
  AuthRepositoryContract? authRepo,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      if (authRepo != null)
        authRepositoryProvider.overrideWith((ref) => authRepo),
      currentUserProvider.overrideWith((ref) => user),
      isEmailPasswordUserProvider.overrideWith((ref) => isEmailPassword),
      subscriptionProvider.overrideWith(
        () => _FakeSubscriptionNotifier(const SubscriptionState()),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      // Mount the drawer inside a Scaffold + opener button so it's actually
      // rendered (a drawer alone never inflates).
      home: Builder(
        builder: (context) => Scaffold(
          drawer: const AppDrawer(),
          body: Center(
            child: Builder(
              builder: (ctx) => FilledButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('header renders the user name and email', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(user: _alice()));
    await _openDrawer(tester);

    expect(find.text('Alice Doe'), findsAtLeastNWidgets(1));
    expect(find.text('alice@example.com'), findsOneWidget);
  });

  testWidgets('header falls back to "Usuario" placeholder without a user',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await _openDrawer(tester);

    // displayUser (Spanish): "Usuario"
    expect(find.text('Usuario'), findsOneWidget);
  });

  testWidgets('renders all top-level menu items', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(user: _alice()));
    await _openDrawer(tester);

    expect(find.text('Nombre de usuario'), findsOneWidget);
    expect(find.text('Cambiar contraseña'), findsOneWidget);
    expect(find.text('Ajustes de la app'), findsOneWidget);
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.text('Plan PRO'), findsOneWidget);
    expect(find.text('Código promocional'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Eliminar cuenta'), findsOneWidget);
  });

  testWidgets('change-password row is hidden for non email/password users',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(user: _alice(), isEmailPassword: false));
    await _openDrawer(tester);

    expect(find.text('Cambiar contraseña'), findsNothing);
    // Other rows still render.
    expect(find.text('Nombre de usuario'), findsOneWidget);
  });

  testWidgets('PRO badge is visible when user is not PRO', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(user: _alice()));
    await _openDrawer(tester);

    // The ProBadge widget renders the literal "PRO" text.
    expect(find.text('PRO'), findsOneWidget);
  });

  group('logout confirmation', () {
    testWidgets('tap shows dialog; cancel does NOT sign out', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final authRepo = MockAuthRepository();
      when(() => authRepo.signOut()).thenAnswer((_) async {});

      await tester.pumpWidget(_wrap(user: _alice(), authRepo: authRepo));
      await _openDrawer(tester);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => authRepo.signOut());
      expect(find.text('¿Cerrar sesión?'), findsNothing);
    });

    testWidgets('confirm calls signOut', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final authRepo = MockAuthRepository();
      when(() => authRepo.signOut()).thenAnswer((_) async {});

      await tester.pumpWidget(_wrap(user: _alice(), authRepo: authRepo));
      await _openDrawer(tester);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      verify(() => authRepo.signOut()).called(1);
    });
  });
}
