import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey);
    if (saved == 'dark') return ThemeMode.dark;
    if (saved == 'light') return ThemeMode.light;
    // Primera vez: detectar brillo del sistema
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final next = (state.valueOrNull ?? ThemeMode.light) == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, next == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
