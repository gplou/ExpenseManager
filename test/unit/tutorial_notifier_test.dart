import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_app/features/tutorial/tutorial_notifier.dart';
import 'package:productivity_app/features/tutorial/tutorial_step.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── TutorialState ───────────────────────────────────────────────────────────

  group('TutorialState', () {
    test('inactive constant has isActive=false and stepIndex=0', () {
      expect(TutorialState.inactive.isActive, isFalse);
      expect(TutorialState.inactive.stepIndex, 0);
    });

    test('isLastStep is true when stepIndex == kTutorialStepCount - 1', () {
      const lastStep = TutorialState(
        isActive: true,
        stepIndex: kTutorialStepCount - 1,
      );
      expect(lastStep.isLastStep, isTrue);
    });

    test('isLastStep is false for earlier steps', () {
      const state = TutorialState(isActive: true, stepIndex: 0);
      expect(state.isLastStep, isFalse);
    });

    test('copyWith updates only the provided fields', () {
      const state = TutorialState(isActive: false, stepIndex: 2);
      final copy = state.copyWith(isActive: true);

      expect(copy.isActive, isTrue);
      expect(copy.stepIndex, 2);
    });

    test('copyWith with no args returns equivalent state', () {
      const state = TutorialState(isActive: true, stepIndex: 3);
      final copy = state.copyWith();

      expect(copy.isActive, state.isActive);
      expect(copy.stepIndex, state.stepIndex);
    });
  });

  // ── TutorialNotifier ────────────────────────────────────────────────────────

  group('TutorialNotifier', () {
    test('initial state is inactive', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(tutorialProvider);
      expect(state.isActive, isFalse);
      expect(state.stepIndex, 0);
    });

    test('start activates the tutorial at step 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tutorialProvider.notifier).start();

      final state = container.read(tutorialProvider);
      expect(state.isActive, isTrue);
      expect(state.stepIndex, 0);
    });

    test('next advances the step index', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tutorialProvider.notifier).start();
      container.read(tutorialProvider.notifier).next();

      expect(container.read(tutorialProvider).stepIndex, 1);
    });

    test('next on last step ends the tutorial', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tutorialProvider.notifier).start();

      // Advance to the last step
      for (int i = 0; i < kTutorialStepCount - 1; i++) {
        container.read(tutorialProvider.notifier).next();
      }
      expect(container.read(tutorialProvider).isLastStep, isTrue);

      // One more next should complete the tutorial
      await Future.microtask(
          () => container.read(tutorialProvider.notifier).next());

      expect(container.read(tutorialProvider).isActive, isFalse);
    });

    test('next does nothing when tutorial is not active', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tutorialProvider.notifier).next();

      final state = container.read(tutorialProvider);
      expect(state.isActive, isFalse);
      expect(state.stepIndex, 0);
    });

    test('skip ends the tutorial immediately', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tutorialProvider.notifier).start();
      await Future.microtask(
          () => container.read(tutorialProvider.notifier).skip());

      expect(container.read(tutorialProvider).isActive, isFalse);
    });

    test('skip persists seen flag to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tutorialProvider.notifier).start();
      await Future.microtask(
          () => container.read(tutorialProvider.notifier).skip());

      // hasSeen reads directly from SharedPreferences
      final seen =
          await container.read(tutorialProvider.notifier).hasSeen();
      expect(seen, isTrue);
    });

    test('hasSeen returns false before any tutorial completion', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final seen =
          await container.read(tutorialProvider.notifier).hasSeen();
      expect(seen, isFalse);
    });

    test('hasSeen returns true when prefs already has the flag', () async {
      SharedPreferences.setMockInitialValues(
          {'interactive_tutorial_seen_v1': true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final seen =
          await container.read(tutorialProvider.notifier).hasSeen();
      expect(seen, isTrue);
    });
  });
}
