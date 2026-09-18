import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'keyword_matcher.dart';

/// Guesses expense vs. income from keywords, per locale. Defaults to
/// [TransactionType.expense] when ambiguous, matching the previous AI
/// prompt's behavior.
class TransactionTypeDetector {
  const TransactionTypeDetector._();

  static const _incomeKeywords = <String, List<String>>{
    'es': [
      'ingreso', 'ingresé', 'ingrese', 'cobré', 'cobre', 'cobro',
      'nómina', 'nomina', 'salario', 'sueldo', 'me pagaron', 'recibí', 'recibi',
    ],
    'en': [
      'income', 'earned', 'got paid', 'salary', 'paycheck', 'paid me',
      'received', 'deposit',
    ],
    'fr': [
      'revenu', 'salaire', 'reçu', 'recu', 'paie', 'encaissé', 'encaisse',
      "j'ai été payé", 'jai ete paye',
    ],
    'de': [
      'einkommen', 'gehalt', 'lohn', 'erhalten', 'einnahme',
      'bezahlt bekommen', 'überwiesen bekommen', 'uberwiesen bekommen',
    ],
  };

  static TransactionType detect(String text, String langCode) {
    final lower = text.toLowerCase();
    final keywords = _incomeKeywords[langCode] ?? _incomeKeywords['en']!;
    final isIncome = KeywordMatcher.containsAnyWord(lower, keywords);
    return isIncome ? TransactionType.income : TransactionType.expense;
  }
}
