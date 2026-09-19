import 'amount_extractor.dart';
import 'keyword_matcher.dart';

/// Finds the total amount in OCR'd receipt lines. Printed receipts can be
/// in any language regardless of the app's locale (e.g. a receipt
/// photographed abroad), so keywords from all 4 locales are always
/// searched, unlike voice parsing where the spoken language matches the
/// app locale.
class ReceiptAmountFinder {
  const ReceiptAmountFinder._();

  static const _totalKeywords = [
    'total', 'importe', 'a pagar', 'suma', 'total a pagar',
    'amount', 'total due', 'balance due',
    'montant', "total à payer", 'total a payer',
    'betrag', 'summe', 'gesamtbetrag', 'zu zahlen',
  ];

  /// Looks for a line naming the total, then the largest number on (or just
  /// after) that line; falls back to the largest number anywhere in the
  /// receipt — the total is typically the biggest number printed.
  ///
  /// Real OCR output is noisy: line splitting can put a receipt's labels and
  /// values in unrelated blocks, and "TOTAL" itself can get misread (e.g.
  /// "IOTAL"), so the keyword search alone isn't reliable enough. Amounts
  /// are always considered currency-shaped (`17.50`, not `17`) first, since
  /// that's what excludes a printed year/ticket-number/time from ever
  /// winning as "the largest number on the receipt".
  static double? find(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (KeywordMatcher.containsAnyWord(lower, _totalKeywords)) {
        final amount = _bestAmountIn(lines[i]) ??
            (i + 1 < lines.length ? _bestAmountIn(lines[i + 1]) : null);
        if (amount != null) return amount;
      }
    }

    final decimals = AmountExtractor.extractDecimalAmounts(lines.join(' '));
    if (decimals.isNotEmpty) {
      return decimals.reduce((a, b) => a > b ? a : b);
    }
    return AmountExtractor.largestIn(lines.join(' '));
  }

  static double? _bestAmountIn(String line) {
    final decimals = AmountExtractor.extractDecimalAmounts(line);
    if (decimals.isNotEmpty) return decimals.reduce((a, b) => a > b ? a : b);
    return AmountExtractor.largestIn(line);
  }
}
