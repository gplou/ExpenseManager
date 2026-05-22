import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/services/analytics_route_observer.dart';

/// We can't easily mock the PostHog SDK here (no injection point), but we
/// can still exercise the [didPush] / [didReplace] branches and verify
/// they don't throw for either named, unnamed, or null routes. The
/// PostHog plugin call itself is a no-op on the test platform (no native
/// channel registered) and swallows errors silently.
void main() {
  // Posthog().screen(...) hits a real MethodChannel under the hood.
  // Register a no-op handler so the call doesn't blow up the test env.
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('posthog_flutter');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  late AnalyticsRouteObserver observer;

  setUp(() {
    observer = AnalyticsRouteObserver();
  });

  PageRoute<void> makeRoute({String? name}) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => const SizedBox.shrink(),
    );
  }

  test('didPush with a named route does not throw', () {
    expect(() => observer.didPush(makeRoute(name: '/dashboard'), null),
        returnsNormally);
  });

  test('didPush with an unnamed route does not throw', () {
    expect(() => observer.didPush(makeRoute(), null), returnsNormally);
  });

  test('didPush with an empty name does not throw', () {
    expect(() => observer.didPush(makeRoute(name: ''), null), returnsNormally);
  });

  test('didReplace with both new and old routes does not throw', () {
    expect(
      () => observer.didReplace(
        newRoute: makeRoute(name: '/new'),
        oldRoute: makeRoute(name: '/old'),
      ),
      returnsNormally,
    );
  });

  test('didReplace with newRoute=null does not throw', () {
    expect(
      () => observer.didReplace(newRoute: null, oldRoute: makeRoute(name: '/x')),
      returnsNormally,
    );
  });
}
