import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingKey = 'has_seen_onboarding';

class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingKey) ?? false;
  }

  Future<void> markSeen() async {
    state = const AsyncData(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
  }
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
