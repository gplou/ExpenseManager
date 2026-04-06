import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/providers/widget_action_provider.dart';

void main() {
  group('pendingWidgetActionProvider', () {
    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pendingWidgetActionProvider), isNull);
    });

    test('can be set to "voice"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(pendingWidgetActionProvider.notifier).state = 'voice';
      expect(container.read(pendingWidgetActionProvider), 'voice');
    });

    test('can be set to "add"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(pendingWidgetActionProvider.notifier).state = 'add';
      expect(container.read(pendingWidgetActionProvider), 'add');
    });

    test('can be reset to null after being set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(pendingWidgetActionProvider.notifier).state = 'voice';
      container.read(pendingWidgetActionProvider.notifier).state = null;

      expect(container.read(pendingWidgetActionProvider), isNull);
    });

    test('updating state notifies listeners', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final values = <String?>[];
      container.listen(
        pendingWidgetActionProvider,
        (_, next) => values.add(next),
      );

      container.read(pendingWidgetActionProvider.notifier).state = 'voice';
      container.read(pendingWidgetActionProvider.notifier).state = null;

      expect(values, ['voice', null]);
    });
  });
}
