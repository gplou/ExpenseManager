/// Simple sliding-window rate limiter for AI parse calls (voice + image).
///
/// Shared singleton so both voice and image parsing count toward the same
/// per-minute quota.
class AiRateLimiter {
  AiRateLimiter._();
  static final instance = AiRateLimiter._();

  static const int maxPerMinute = 7;
  static const _window = Duration(minutes: 1);

  final List<DateTime> _timestamps = [];

  /// Returns `true` if the call is allowed, `false` if rate-limited.
  bool tryConsume() {
    final now = DateTime.now();
    _timestamps.removeWhere((t) => now.difference(t) > _window);
    if (_timestamps.length >= maxPerMinute) return false;
    _timestamps.add(now);
    return true;
  }
}
