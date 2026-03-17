import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/core/utils/ai_rate_limiter.dart';

void main() {
  group('AiRateLimiter', () {
    late AiRateLimiter limiter;

    setUp(() {
      // Use a fresh instance for each test to avoid state leaking
      limiter = AiRateLimiter.testInstance();
    });

    test('allows up to maxPerMinute calls', () {
      for (var i = 0; i < AiRateLimiter.maxPerMinute; i++) {
        expect(limiter.tryConsume(), isTrue, reason: 'Call $i should be allowed');
      }
    });

    test('blocks calls beyond maxPerMinute', () {
      for (var i = 0; i < AiRateLimiter.maxPerMinute; i++) {
        limiter.tryConsume();
      }
      expect(limiter.tryConsume(), isFalse);
    });
  });
}
