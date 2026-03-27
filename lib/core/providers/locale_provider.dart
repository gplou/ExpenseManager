import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'locale_code';

const supportedLocales = [
  (code: 'es', flag: '🇪🇸', name: 'Español'),
  (code: 'en', flag: '🇬🇧', name: 'English'),
  (code: 'fr', flag: '🇫🇷', name: 'Français'),
  (code: 'de', flag: '🇩🇪', name: 'Deutsch'),
];

Locale _resolveDeviceLocale() {
  final deviceCode =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final supported = supportedLocales.map((e) => e.code).toSet();
  return supported.contains(deviceCode)
      ? Locale(deviceCode)
      : const Locale('en');
}

class LocaleNotifier extends AsyncNotifier<Locale> {
  @override
  Future<Locale> build() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    final locale = code != null ? Locale(code) : _resolveDeviceLocale();
    Intl.defaultLocale = locale.languageCode;
    return locale;
  }

  Future<void> setLocale(Locale locale) async {
    Intl.defaultLocale = locale.languageCode;
    state = AsyncData(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}

final localeProvider =
    AsyncNotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
