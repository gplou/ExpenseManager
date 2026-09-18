import 'package:clock/clock.dart';

import 'keyword_matcher.dart';

/// Resolves simple relative-date phrases ("hoy", "ayer", "el lunes" and
/// equivalents) against [clock.now()]. Complex phrases ("hace tres días")
/// are out of scope — callers should default to today when this returns
/// null, same as the previous AI prompt's fallback.
class DatePhraseParser {
  const DatePhraseParser._();

  static const _todayWords = <String, List<String>>{
    'es': ['hoy'],
    'en': ['today'],
    'fr': ["aujourd'hui", 'aujourdhui'],
    'de': ['heute'],
  };

  static const _yesterdayWords = <String, List<String>>{
    'es': ['ayer'],
    'en': ['yesterday'],
    'fr': ['hier'],
    'de': ['gestern'],
  };

  /// Weekday name -> ISO weekday number ([DateTime.monday]..[DateTime.sunday]),
  /// per locale. Includes unaccented variants for STT transcripts that drop
  /// accents.
  static const _weekdays = <String, Map<String, int>>{
    'es': {
      'lunes': DateTime.monday,
      'martes': DateTime.tuesday,
      'miércoles': DateTime.wednesday,
      'miercoles': DateTime.wednesday,
      'jueves': DateTime.thursday,
      'viernes': DateTime.friday,
      'sábado': DateTime.saturday,
      'sabado': DateTime.saturday,
      'domingo': DateTime.sunday,
    },
    'en': {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    },
    'fr': {
      'lundi': DateTime.monday,
      'mardi': DateTime.tuesday,
      'mercredi': DateTime.wednesday,
      'jeudi': DateTime.thursday,
      'vendredi': DateTime.friday,
      'samedi': DateTime.saturday,
      'dimanche': DateTime.sunday,
    },
    'de': {
      'montag': DateTime.monday,
      'dienstag': DateTime.tuesday,
      'mittwoch': DateTime.wednesday,
      'donnerstag': DateTime.thursday,
      'freitag': DateTime.friday,
      'samstag': DateTime.saturday,
      'sonntag': DateTime.sunday,
    },
  };

  static DateTime? resolve(String text, String langCode) {
    final lower = text.toLowerCase();
    final lang = _weekdays.containsKey(langCode) ? langCode : 'en';
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);

    if (KeywordMatcher.containsAnyWord(
      lower,
      _todayWords[lang] ?? _todayWords['en']!,
    )) {
      return today;
    }
    if (KeywordMatcher.containsAnyWord(
      lower,
      _yesterdayWords[lang] ?? _yesterdayWords['en']!,
    )) {
      return today.subtract(const Duration(days: 1));
    }

    for (final entry in _weekdays[lang]!.entries) {
      if (KeywordMatcher.containsWord(lower, entry.key)) {
        // Most recent past (or today's) occurrence of that weekday.
        var diff = today.weekday - entry.value;
        if (diff < 0) diff += 7;
        return today.subtract(Duration(days: diff));
      }
    }
    return null;
  }
}
