/// Whole-word keyword search over already-lowercased text.
///
/// Plain `String.contains` matches a keyword inside an unrelated longer
/// word — `total` inside `subtotal`, `gas` inside `gasté`, `ropa` inside
/// `Europa`, `anual` inside `manual`, `earned` inside `learned`. A regex
/// `\b` doesn't fix this either: it only treats ASCII letters as word
/// characters, so `\bcafé\b` fails to match `café` (the accented `é` isn't
/// `\w`). This checks Unicode letters on both sides of the match instead.
class KeywordMatcher {
  const KeywordMatcher._();

  static final _letter = RegExp(r'\p{L}', unicode: true);

  static bool containsWord(String haystack, String needle) {
    var start = 0;
    while (true) {
      final idx = haystack.indexOf(needle, start);
      if (idx == -1) return false;
      final before = idx > 0 ? haystack[idx - 1] : '';
      final afterIndex = idx + needle.length;
      final after = afterIndex < haystack.length ? haystack[afterIndex] : '';
      final boundaryBefore = before.isEmpty || !_letter.hasMatch(before);
      final boundaryAfter = after.isEmpty || !_letter.hasMatch(after);
      if (boundaryBefore && boundaryAfter) return true;
      start = idx + 1;
    }
  }

  static bool containsAnyWord(String haystack, Iterable<String> needles) =>
      needles.any((needle) => containsWord(haystack, needle));
}
