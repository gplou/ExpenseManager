import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/tutorial/tutorial_keys.dart';
import 'package:expense_manager/features/tutorial/tutorial_step.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('es'));
  });

  test('kTutorialStepCount matches the list length', () {
    final steps = buildTutorialSteps(l10n);
    expect(steps.length, kTutorialStepCount);
  });

  test('all step titles and bodies are non-empty', () {
    for (final step in buildTutorialSteps(l10n)) {
      expect(step.title, isNotEmpty, reason: 'title for $step');
      expect(step.body, isNotEmpty, reason: 'body for $step');
    }
  });

  test('FAB step is first and targets fabKey', () {
    final steps = buildTutorialSteps(l10n);
    expect(steps.first.targetKey, TutorialKeys.fabKey);
  });

  test('only the chat step is marked skipIfKeyMissing (PRO-gated)', () {
    final skippable = buildTutorialSteps(l10n)
        .where((s) => s.skipIfKeyMissing)
        .toList();
    expect(skippable, hasLength(1));
    expect(skippable.single.targetKey, TutorialKeys.chatBtnKey);
  });

  test('SpeedDial-targeting steps (1-3) wait for the open animation', () {
    final steps = buildTutorialSteps(l10n);
    for (var i = 1; i <= 3; i++) {
      expect(
        steps[i].measureDelay.inMilliseconds,
        greaterThanOrEqualTo(300),
        reason: 'step $i should wait for the dial animation',
      );
    }
  });

  test('defaults apply when constructor arguments are omitted', () {
    final step = TutorialStep(
      title: 't',
      body: 'b',
      targetKey: GlobalKey(),
    );
    expect(step.spotlightPadding, 14.0);
    expect(step.spotlightRadius, 18.0);
    expect(step.measureDelay, Duration.zero);
    expect(step.skipIfKeyMissing, isFalse);
    expect(step.icon, isNull);
  });
}
