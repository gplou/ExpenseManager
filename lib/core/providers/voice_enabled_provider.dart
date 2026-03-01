import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kVoiceEnabledKey = 'voice_enabled';

class VoiceEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kVoiceEnabledKey) ?? false;
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? false;
    state = AsyncData(!current);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoiceEnabledKey, !current);
  }
}

final voiceEnabledProvider =
    AsyncNotifierProvider<VoiceEnabledNotifier, bool>(VoiceEnabledNotifier.new);
