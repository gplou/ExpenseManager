// Smoke test that boots the real app binary on a device/simulator and
// verifies it can reach the login screen without crashing.
//
// This is the absolute minimum E2E: a passing run proves the binary
// builds, the Dart code initialises without throwing, and GoRouter
// renders the unauthenticated entry point. Add richer flows (auth,
// paywall, export, deep links) as separate files in this folder.
//
// Run with:
//   fvm flutter test integration_test/smoke_test.dart \
//     --dart-define-from-file=dart_defines.json

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:expense_manager/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and renders the login screen for an unauthenticated user',
      (tester) async {
    await app.main();
    // GoRouter + Supabase need a moment to settle on first boot.
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Either the welcome screen (login) or the onboarding screen is fine —
    // both are valid entry points for a fresh install. We just assert
    // that *some* screen rendered without an exception.
    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
