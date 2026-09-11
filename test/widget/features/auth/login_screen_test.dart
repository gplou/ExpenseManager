import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/auth/data/auth_repository.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/screens/login_screen.dart';
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
        home: const LoginScreen(),
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

  testWidgets('renders welcome heading and form fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
  });

  testWidgets('shows validation error when fields are empty', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu email'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('shows email-format error for an invalid address',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'somepass');

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Email inválido'), findsOneWidget);
  });

  testWidgets('valid input calls signInWithEmail on the repository',
      (tester) async {
    // Use a never-completing future so the post-sign-in navigation
    // (context.go) never fires — the test only cares that the repo
    // was called with the right args.
    final completer = Completer<UserModel>();
    when(() => repo.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) => completer.future);

    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'a@b.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'mypassword');

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump(); // schedule the async call

    verify(() => repo.signInWithEmail(
          email: 'a@b.com',
          password: 'mypassword',
        )).called(1);
  });

  testWidgets('password visibility toggle changes the obscure state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Initially obscured → visibility_outlined icon present
    expect(find.byIcon(PhosphorIcons.eye()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.eyeSlash()), findsNothing);

    await tester.tap(find.byIcon(PhosphorIcons.eye()));
    await tester.pumpAndSettle();

    expect(find.byIcon(PhosphorIcons.eyeSlash()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.eye()), findsNothing);
  });
}
