import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/app_lock_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppLockNotifier', () {
    test('defaults to disabled when no prefs saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(appLockProvider.future), isFalse);
    });

    test('loads enabled=true from prefs', () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(appLockProvider.future), isTrue);
    });

    test('setEnabled updates state and persists across containers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appLockProvider.future);

      await container.read(appLockProvider.notifier).setEnabled(true);
      expect(container.read(appLockProvider).value, isTrue);

      // Un contenedor nuevo (≈ reinicio de la app) lee el valor persistido.
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      expect(await fresh.read(appLockProvider.future), isTrue);
    });
  });
}
