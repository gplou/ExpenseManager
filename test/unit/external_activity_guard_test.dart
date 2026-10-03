import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/services/external_activity_guard.dart';

void main() {
  test('is active only while the wrapped action is pending', () async {
    final completer = Completer<String>();
    expect(ExternalActivityGuard.isActive, isFalse);

    final future = ExternalActivityGuard.run(() => completer.future);
    expect(ExternalActivityGuard.isActive, isTrue);

    completer.complete('ok');
    expect(await future, 'ok');
    expect(ExternalActivityGuard.isActive, isFalse);
  });

  test('clears the mark when the action throws', () async {
    await expectLater(
      ExternalActivityGuard.run<void>(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(ExternalActivityGuard.isActive, isFalse);
  });

  test('overlapping calls keep the mark until the last one finishes', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    final a = ExternalActivityGuard.run(() => first.future);
    final b = ExternalActivityGuard.run(() => second.future);

    first.complete();
    await a;
    expect(ExternalActivityGuard.isActive, isTrue);

    second.complete();
    await b;
    expect(ExternalActivityGuard.isActive, isFalse);
  });
}
