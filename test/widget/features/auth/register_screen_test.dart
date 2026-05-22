import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/auth/data/auth_repository.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/screens/register_screen.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../../../helpers/mocks.dart';

Widget _wrap(MockAuthRepository repo) => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: const RegisterScreen(),
      ),
    );

void main() {
  setUpAll(registerCommonFallbacks);

  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.authStateChanges).thenAnswer((_) => const Stream.empty());
    when(() => repo.currentUser).thenReturn(null);
  });

  testWidgets('renders all three form fields and Create-account heading',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsAtLeastNWidgets(1));
    expect(find.widgetWithText(TextFormField, 'Nombre'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contraseña'), findsOneWidget);
  });

  testWidgets('shows validation errors when fields are empty',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Submit empty form
    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu nombre'), findsOneWidget);
    expect(find.text('Ingresa tu email'), findsOneWidget);
  });

  testWidgets('rejects passwords shorter than the minimum length',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Me');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'me@x.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'a1');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    // The validator should mark the password as too short.
    expect(find.textContaining('contraseña'), findsWidgets);
    verifyNever(() => repo.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ));
  });

  testWidgets('valid input invokes signUpWithEmail on the repository',
      (tester) async {
    // Use a never-completing future so the post-sign-up navigation
    // (context.go) never fires — the test only cares that the repo
    // was called with the right args.
    final completer = Completer<UserModel>();
    when(() => repo.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        )).thenAnswer((_) => completer.future);

    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Me');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'me@x.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'longenough1');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pump();

    verify(() => repo.signUpWithEmail(
          email: 'me@x.com',
          password: 'longenough1',
          name: 'Me',
        )).called(1);
  });
}
