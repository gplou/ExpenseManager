import 'package:flutter_test/flutter_test.dart';
import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/features/subscription/subscription_repository.dart';

import '../../helpers/mocks.dart';

/// Builds a CustomerInfo mock with one active `pro` entitlement from
/// [store] and an optional [expirationDate]. Mirrors the shape that
/// RevenueCatAdapter.fromCustomerInfo expects.
CustomerInfo _customerInfoWithPro({
  Store store = Store.appStore,
  String? expirationDate,
}) {
  final entitlement = MockEntitlementInfo();
  when(() => entitlement.store).thenReturn(store);
  when(() => entitlement.expirationDate).thenReturn(expirationDate);

  final entitlements = _MockEntitlementInfos();
  when(() => entitlements.active).thenReturn({'pro': entitlement});

  final info = MockCustomerInfo();
  when(() => info.entitlements).thenReturn(entitlements);
  return info;
}

CustomerInfo _customerInfoWithoutPro() {
  final entitlements = _MockEntitlementInfos();
  when(() => entitlements.active).thenReturn({});

  final info = MockCustomerInfo();
  when(() => info.entitlements).thenReturn(entitlements);
  return info;
}

class _MockEntitlementInfos extends Mock implements EntitlementInfos {}

class _MockPurchasesError extends Mock implements PurchasesError {}

void main() {
  setUpAll(() {
    registerCommonFallbacks();
  });

  late MockPurchasesGateway purchases;
  late SubscriptionRepository repo;

  setUp(() {
    purchases = MockPurchasesGateway();
    // The repo's Supabase-side methods aren't exercised here; just give it
    // a working real client wired to a mock HTTP backend so the constructor
    // doesn't need extra plumbing.
    final supabase = SupabaseClient(
      'https://mock.supabase.co',
      'fake',
      httpClient: MockSupabaseHttpClient(),
    );
    repo = SubscriptionRepository(supabase, purchases);
  });

  // ── purchaseProPlan ──────────────────────────────────────────────────────

  group('purchaseProPlan', () {
    test('returns RCPurchaseResult mapped from the gateway response',
        () async {
      final pkg = MockPackage();
      when(() => purchases.purchasePackage(pkg)).thenAnswer(
        (_) async => _customerInfoWithPro(
          store: Store.appStore,
          expirationDate: '2026-12-31T00:00:00Z',
        ),
      );

      final result = await repo.purchaseProPlan(pkg);

      expect(result.isPro, isTrue);
      expect(result.source, 'app_store');
      expect(result.expiresAt, DateTime.parse('2026-12-31T00:00:00Z').toLocal());
    });

    test('returns isPro=false when the response has no active entitlement',
        () async {
      final pkg = MockPackage();
      when(() => purchases.purchasePackage(pkg))
          .thenAnswer((_) async => _customerInfoWithoutPro());

      final result = await repo.purchaseProPlan(pkg);

      expect(result.isPro, isFalse);
      expect(result.source, 'unknown');
    });

    test(
        'throws RCPurchaseCancelledException when the gateway reports user cancel',
        () async {
      final pkg = MockPackage();
      final err = _MockPurchasesError();
      when(() => err.code).thenReturn(PurchasesErrorCode.purchaseCancelledError);
      when(() => err.message).thenReturn('cancelled');
      when(() => purchases.purchasePackage(pkg)).thenThrow(err);

      await expectLater(
        () => repo.purchaseProPlan(pkg),
        throwsA(isA<RCPurchaseCancelledException>()),
      );
    });

    test('wraps any other PurchasesError into RCPurchaseException',
        () async {
      final pkg = MockPackage();
      final err = _MockPurchasesError();
      when(() => err.code).thenReturn(PurchasesErrorCode.networkError);
      when(() => err.message).thenReturn('network down');
      when(() => purchases.purchasePackage(pkg)).thenThrow(err);

      await expectLater(
        () => repo.purchaseProPlan(pkg),
        throwsA(
          isA<RCPurchaseException>()
              .having((e) => e.message, 'message', 'network down'),
        ),
      );
    });
  });

  // ── restoreProPlan ───────────────────────────────────────────────────────

  group('restoreProPlan', () {
    test('returns mapped result when the gateway succeeds', () async {
      when(() => purchases.restorePurchases()).thenAnswer(
        (_) async => _customerInfoWithPro(store: Store.playStore),
      );

      final result = await repo.restoreProPlan();

      expect(result.isPro, isTrue);
      expect(result.source, 'play_store');
    });

    test('throws RCPurchaseException on any PurchasesError', () async {
      final err = _MockPurchasesError();
      when(() => err.code).thenReturn(PurchasesErrorCode.networkError);
      when(() => err.message).thenReturn('no internet');
      when(() => purchases.restorePurchases()).thenThrow(err);

      await expectLater(
        () => repo.restoreProPlan(),
        throwsA(isA<RCPurchaseException>()),
      );
    });
  });

  // ── getCurrentRCStatus ───────────────────────────────────────────────────

  group('getCurrentRCStatus', () {
    test('returns the mapped result when the gateway succeeds', () async {
      when(() => purchases.getCustomerInfo()).thenAnswer(
        (_) async => _customerInfoWithPro(store: Store.appStore),
      );

      final result = await repo.getCurrentRCStatus();

      expect(result, isNotNull);
      expect(result!.isPro, isTrue);
    });

    test('returns null on any exception (RC may be unavailable)', () async {
      when(() => purchases.getCustomerInfo()).thenThrow(Exception('boom'));

      final result = await repo.getCurrentRCStatus();

      expect(result, isNull);
    });
  });
}
