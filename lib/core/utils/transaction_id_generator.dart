import 'dart:math';

/// Generates UUID v4 strings compatible with Supabase's uuid column type.
class TransactionIdGenerator {
  const TransactionIdGenerator._();

  static final _rng = Random.secure();

  /// Generates a random UUID v4 (e.g. `550e8400-e29b-41d4-a716-446655440000`).
  static String generate([String? userId]) {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
