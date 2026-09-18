import 'keyword_matcher.dart';

/// Result of scanning text for a recurrence phrase.
class RecurrencePhraseResult {
  const RecurrencePhraseResult(this.isRecurring, this.recurrenceType);

  final bool isRecurring;

  /// One of 'weekly' | 'monthly' | 'annual', or null when not recurring.
  final String? recurrenceType;
}

/// Detects recurrence keywords ("cada mes", "recurrente", "every month" and
/// equivalents). Defaults to 'monthly' when a generic recurrence phrase is
/// found without an explicit frequency — same default the previous AI
/// prompt used.
class RecurrencePhraseDetector {
  const RecurrencePhraseDetector._();

  static const _weeklyWords = <String, List<String>>{
    'es': ['cada semana', 'semanal', 'semanalmente'],
    'en': ['every week', 'weekly'],
    'fr': ['chaque semaine', 'hebdomadaire'],
    'de': ['jede woche', 'wöchentlich', 'wochentlich'],
  };

  static const _monthlyWords = <String, List<String>>{
    'es': ['cada mes', 'mensual', 'mensualmente'],
    'en': ['every month', 'monthly'],
    'fr': ['chaque mois', 'mensuel', 'mensuelle'],
    'de': ['jeden monat', 'monatlich'],
  };

  static const _annualWords = <String, List<String>>{
    'es': ['cada año', 'cada ano', 'anual', 'anualmente'],
    'en': ['every year', 'yearly', 'annual', 'annually'],
    'fr': ['chaque année', 'chaque annee', 'annuel', 'annuelle'],
    'de': ['jedes jahr', 'jährlich', 'jahrlich'],
  };

  static const _genericWords = <String, List<String>>{
    'es': ['recurrente', 'recurrencia'],
    'en': ['recurring', 'recurrence'],
    'fr': ['récurrent', 'recurrent', 'récurrente', 'recurrente'],
    'de': ['wiederkehrend'],
  };

  static RecurrencePhraseResult detect(String text, String langCode) {
    final lower = text.toLowerCase();
    final lang = _monthlyWords.containsKey(langCode) ? langCode : 'en';

    if (KeywordMatcher.containsAnyWord(lower, _weeklyWords[lang] ?? const [])) {
      return const RecurrencePhraseResult(true, 'weekly');
    }
    if (KeywordMatcher.containsAnyWord(lower, _annualWords[lang] ?? const [])) {
      return const RecurrencePhraseResult(true, 'annual');
    }
    if (KeywordMatcher.containsAnyWord(
          lower,
          _monthlyWords[lang] ?? const [],
        ) ||
        KeywordMatcher.containsAnyWord(
          lower,
          _genericWords[lang] ?? const [],
        )) {
      return const RecurrencePhraseResult(true, 'monthly');
    }
    return const RecurrencePhraseResult(false, null);
  }
}
