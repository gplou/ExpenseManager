import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/tutorial/tutorial_notifier.dart';
import 'package:expense_manager/features/tutorial/tutorial_overlay.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('renders nothing when the tutorial is inactive',
      (tester) async {
    await tester.pumpWidget(_wrap(const TutorialOverlay()));
    await tester.pumpAndSettle();

    // Skip button is only present when overlay is rendered → absence proves
    // the overlay is hidden.
    expect(find.text('Saltar'), findsNothing);
  });

  testWidgets('start() activates the overlay; skip() hides it again',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(tutorialProvider).isActive, isFalse);

    container.read(tutorialProvider.notifier).start();
    expect(container.read(tutorialProvider).isActive, isTrue);
    expect(container.read(tutorialProvider).stepIndex, 0);

    container.read(tutorialProvider.notifier).next();
    expect(container.read(tutorialProvider).stepIndex, 1);

    container.read(tutorialProvider.notifier).previous();
    expect(container.read(tutorialProvider).stepIndex, 0);

    container.read(tutorialProvider.notifier).skip();
    expect(container.read(tutorialProvider).isActive, isFalse);
  });

  testWidgets('previous() is a no-op at step 0', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(tutorialProvider.notifier).start();
    container.read(tutorialProvider.notifier).previous();

    expect(container.read(tutorialProvider).stepIndex, 0);
  });

  testWidgets('next() at the last step completes the tutorial', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final n = container.read(tutorialProvider.notifier);
    n.start();
    for (var i = 0; i < 8; i++) {
      n.next();
    }
    expect(container.read(tutorialProvider).isLastStep, isTrue);

    n.next();
    expect(container.read(tutorialProvider).isActive, isFalse);
  });

  testWidgets('next/previous are no-ops when inactive', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(tutorialProvider.notifier).next();
    container.read(tutorialProvider.notifier).previous();
    expect(container.read(tutorialProvider).isActive, isFalse);
  });

  testWidgets('hasSeen() reflects SharedPreferences markSeen()', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(tutorialProvider.notifier).hasSeen(), isFalse);

    await container.read(tutorialProvider.notifier).markSeen();
    expect(await container.read(tutorialProvider.notifier).hasSeen(), isTrue);
  });
}
