import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins `clock.now()` to [now] for the duration of [body].
///
/// Any code under test that uses `package:clock` (`clock.now()`,
/// `clock.fromNow(...)`, etc.) will see the fixed time. Code that
/// calls `DateTime.now()` directly is **not** affected — see the
/// guidance in `test/README.md` for migrating to `clock.now()`.
///
/// ```dart
/// withFixedClock(DateTime.utc(2026, 5, 21), () {
///   expect(clock.now(), DateTime.utc(2026, 5, 21));
/// });
/// ```
T withFixedClock<T>(DateTime now, T Function() body) {
  return withClock(Clock.fixed(now), body);
}

/// Async variant of [withFixedClock]. Use when [body] is async.
Future<T> withFixedClockAsync<T>(
  DateTime now,
  Future<T> Function() body,
) {
  return withClock(Clock.fixed(now), body);
}

/// Runs [body] inside a [FakeAsync] zone with a pinned clock so that
/// `Future.delayed`, `Timer`, and `clock.now()` are all controllable.
///
/// Use [FakeAsync.elapse] inside [body] to advance time deterministically.
///
/// ```dart
/// withFakeAsyncAndClock(DateTime.utc(2026, 1, 1), (async) {
///   final timer = Timer(const Duration(minutes: 5), () => fired = true);
///   async.elapse(const Duration(minutes: 5));
///   expect(fired, isTrue);
/// });
/// ```
T withFakeAsyncAndClock<T>(
  DateTime now,
  T Function(FakeAsync async) body,
) {
  return fakeAsync(
    (async) => withClock(Clock.fixed(now), () => body(async)),
    initialTime: now,
  );
}

/// Matcher that asserts a [DateTime] is within [tolerance] of [expected].
/// Useful when production code uses `DateTime.now()` directly (so the
/// timestamp can't be pinned exactly).
Matcher closeToDateTime(DateTime expected, {Duration tolerance = const Duration(seconds: 1)}) {
  return predicate<DateTime>(
    (actual) => actual.difference(expected).abs() <= tolerance,
    'within $tolerance of $expected',
  );
}
