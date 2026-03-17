import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tutorial_step.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class TutorialState {
  const TutorialState({
    required this.isActive,
    required this.stepIndex,
  });

  final bool isActive;
  final int stepIndex;

  bool get isLastStep => stepIndex == kTutorialStepCount - 1;

  TutorialState copyWith({bool? isActive, int? stepIndex}) => TutorialState(
        isActive: isActive ?? this.isActive,
        stepIndex: stepIndex ?? this.stepIndex,
      );

  static const inactive = TutorialState(isActive: false, stepIndex: 0);
}

// ── SharedPreferences key ─────────────────────────────────────────────────────

const _kTutorialSeenKey = 'interactive_tutorial_seen_v1';

// ── Notifier ──────────────────────────────────────────────────────────────────

class TutorialNotifier extends Notifier<TutorialState> {
  @override
  TutorialState build() => TutorialState.inactive;

  /// Returns true if the user has already completed (or skipped) the tutorial.
  Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTutorialSeenKey) ?? false;
  }

  /// Starts the tutorial from the first step.
  void start() {
    state = const TutorialState(isActive: true, stepIndex: 0);
  }

  /// Advances to the next step, or ends the tutorial if on the last step.
  void next() {
    if (!state.isActive) return;
    if (state.isLastStep) {
      _complete();
    } else {
      state = state.copyWith(stepIndex: state.stepIndex + 1);
    }
  }

  /// Skips the tutorial and marks it as seen.
  void skip() => _complete();

  Future<void> _complete() async {
    state = TutorialState.inactive;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialSeenKey, true);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final tutorialProvider =
    NotifierProvider<TutorialNotifier, TutorialState>(TutorialNotifier.new);
