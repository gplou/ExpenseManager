import 'dart:math';

/// Centralises transaction ID generation so the format is consistent across
/// local repositories and any future storage backends.
///
/// Format: `<microseconds>_<random>_<userId prefix>`
/// - microseconds: monotonically increasing, provides rough ordering
/// - random int: reduces collision probability when multiple records are
///   created within the same microsecond (e.g. bulk import)
/// - userId prefix: scopes IDs to the owning user without storing full UUIDs
class TransactionIdGenerator {
  const TransactionIdGenerator._();

  static final _rng = Random();

  /// Generates a unique ID scoped to [userId].
  static String generate(String userId) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = _rng.nextInt(0x7FFFFFFF);
    final prefix = userId.length >= 8 ? userId.substring(0, 8) : userId;
    return '${ts}_${rand}_$prefix';
  }
}
