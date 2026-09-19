/// Extracts monetary amounts from free text without any AI/network call.
class AmountExtractor {
  const AmountExtractor._();

  /// A run of digits and `.`/`,` separators, e.g. `20`, `17,50`, `1.234,56`.
  static final _numberToken = RegExp(r'\d[\d.,]*\d|\d');

  /// A number token whose *last* separator is followed by exactly 2 digits
  /// — how currency amounts are printed (`17.50`, `1.234,56`). Plain
  /// integers (years, ticket numbers, times) and thousands-only groupings
  /// (`1.234`) never match this, which is what makes it reliable for
  /// picking an amount out of noisy OCR'd receipt text.
  static final _decimalToken = RegExp(r'\d[\d.,]*[.,]\d{2}(?!\d)');

  static List<double> extractAll(String text) => _numberToken
      .allMatches(text)
      .map((m) => _parseToken(m.group(0)!))
      .toList();

  static List<double> extractDecimalAmounts(String text) => _decimalToken
      .allMatches(text)
      .map((m) => _parseToken(m.group(0)!))
      .toList();

  /// The first amount mentioned — matches how people speak amounts
  /// ("gasté 20 en comida").
  static double? firstIn(String text) {
    final all = extractAll(text);
    return all.isEmpty ? null : all.first;
  }

  /// The largest amount found — receipts print the total as the biggest
  /// number on the ticket.
  static double? largestIn(String text) {
    final all = extractAll(text);
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a > b ? a : b);
  }

  /// Parses a matched number token, treating its *last* `.`/`,` as the
  /// decimal separator only when it's followed by exactly 1-2 digits (how
  /// currency amounts are written); every other `.`/`,` in the token — and
  /// a trailing one followed by 3+ digits, e.g. `1.234` — is a thousands
  /// grouping separator and gets dropped. Handles both `1.234,56` (es/fr/de)
  /// and `1,234.56` (en) without needing to know which locale produced it.
  static double _parseToken(String raw) {
    final lastSep = raw.lastIndexOf(RegExp(r'[.,]'));
    if (lastSep == -1) return double.parse(raw);

    final fractionLength = raw.length - lastSep - 1;
    if (fractionLength == 1 || fractionLength == 2) {
      final wholePart =
          raw.substring(0, lastSep).replaceAll(RegExp(r'[.,]'), '');
      final fractionPart = raw.substring(lastSep + 1);
      return double.parse('$wholePart.$fractionPart');
    }
    return double.parse(raw.replaceAll(RegExp(r'[.,]'), ''));
  }
}
