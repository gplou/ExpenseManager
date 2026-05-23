import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/data/purchases_gateway.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_repository.dart';

import '../../helpers/mocks.dart';

/// Mock for `flutter_secure_storage` — the notifier reads the cache from
/// it on every `build()`. Returning null for every key keeps the path
/// simple ("no cache" → fall through to remote fetch).
const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Posthog plugin sets up its own channel handler on first use.
const _posthogChannel = MethodChannel('posthog_flutter');

UserModel _user(String id) => UserModel(
      id: id,
      email: '$id@x.com',
      isEmailVerified: true,
      createdAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerCommonFallbacks);

  late MockPurchasesGateway purchases;
  late MockSubscriptionRepository repo;

  setUp(() {
    purchases = MockPurchasesGateway();
    repo = MockSubscriptionRepository();

    // Default stubs: no cache, no remote subscription, trial unused.
    when(() => repo.fetchRemoteSubscription())
        .thenAnswer((_) async => (expiresAt: null, source: null));
    when(() => repo.checkTrialUsed()).thenAnswer((_) async => false);
    when(() => repo.getCurrentRCStatus()).thenAnswer((_) async => null);
    when(() => repo.upsertSubscription(
          expiresAt: any(named: 'expiresAt'),
          source: any(named: 'source'),
          storeTxId: any(named: 'storeTxId'),
        )).thenAnswer((_) async {});

    // Mock platform channels that the notifier touches transitively.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      // read returns null, write/delete return null, containsKey returns false.
      if (call.method == 'containsKey') return false;
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_posthogChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_posthogChannel, null);
  });

  ProviderContainer buildContainer({UserModel? user}) {
    final container = ProviderContainer(overrides: [
      purchasesGatewayProvider.overrideWithValue(purchases),
      subscriptionRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => user),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  // ── Listener wiring ──────────────────────────────────────────────────────

  group('build() — listener wiring', () {
    test('registers addCustomerInfoUpdateListener once on first build',
        () async {
      final container = buildContainer();
      await container.read(subscriptionProvider.future);

      verify(() => purchases.addCustomerInfoUpdateListener(any())).called(1);
    });

    test('removes the listener on dispose', () async {
      final container = buildContainer();
      await container.read(subscriptionProvider.future);

      container.dispose();

      verify(() => purchases.removeCustomerInfoUpdateListener(any())).called(1);
    });
  });

  // ── RC identity sync ─────────────────────────────────────────────────────

  group('build() — RC identity', () {
    test('does NOT call logIn when there is no signed-in user', () async {
      final container = buildContainer();
      await container.read(subscriptionProvider.future);

      verifyNever(() => purchases.logIn(any()));
    });

    test('calls logIn(user.id) when a user is signed in', () async {
      final container = buildContainer(user: _user('alice'));
      await container.read(subscriptionProvider.future);

      verify(() => purchases.logIn('alice')).called(1);
      verifyNever(() => purchases.logOut());
    });

    test('dispose calls logOut when an identity was set', () async {
      final container = buildContainer(user: _user('alice'));
      await container.read(subscriptionProvider.future);

      container.dispose();

      verify(() => purchases.logOut()).called(1);
    });

    test('dispose does NOT call logOut when no identity was ever set',
        () async {
      final container = buildContainer();
      await container.read(subscriptionProvider.future);

      container.dispose();

      verifyNever(() => purchases.logOut());
    });
  });

  // ── Initial state hydration ──────────────────────────────────────────────

  group('build() — initial state', () {
    test('fresh user with no cache and no remote → non-PRO', () async {
      final container = buildContainer(user: _user('alice'));
      final state = await container.read(subscriptionProvider.future);

      expect(state.isPro, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.expiresAt, isNull);
      expect(state.trialUsed, isFalse);
    });

    test('fetchRemoteSubscription expiry hydrates state to PRO', () async {
      final future = DateTime.now().add(const Duration(days: 30));
      when(() => repo.fetchRemoteSubscription())
          .thenAnswer((_) async => (expiresAt: future, source: 'app_store'));

      final container = buildContainer(user: _user('alice'));
      final state = await container.read(subscriptionProvider.future);

      expect(state.isPro, isTrue);
      expect(state.source, 'app_store');
    });

    test(
        'RC entitlement with later expiry overrides the Supabase value',
        () async {
      final supaExpiry = DateTime.now().add(const Duration(days: 10));
      final rcExpiry = DateTime.now().add(const Duration(days: 60));

      when(() => repo.fetchRemoteSubscription()).thenAnswer(
        (_) async => (expiresAt: supaExpiry, source: 'app_store'),
      );
      when(() => repo.getCurrentRCStatus()).thenAnswer(
        (_) async => RCPurchaseResult(
          isPro: true,
          source: 'app_store',
          expiresAt: rcExpiry,
        ),
      );

      final container = buildContainer(user: _user('alice'));
      final state = await container.read(subscriptionProvider.future);

      expect(state.isPro, isTrue);
      // Notifier should pick the RC expiry (later than Supabase) and write it
      // back via upsertSubscription.
      verify(() => repo.upsertSubscription(
            expiresAt: rcExpiry,
            source: 'app_store',
            storeTxId: any(named: 'storeTxId'),
          )).called(1);
    });
  });
}
