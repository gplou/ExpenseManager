import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:expense_manager/features/subscription/data/revenue_cat_adapter.dart';
import 'package:expense_manager/features/subscription/subscription_repository.dart';

import '../helpers/mocks.dart';

EntitlementInfo _entitlement({
  required Store store,
  String? expirationDate,
}) {
  final e = MockEntitlementInfo();
  when(() => e.store).thenReturn(store);
  when(() => e.expirationDate).thenReturn(expirationDate);
  return e;
}

CustomerInfo _customerInfo({EntitlementInfo? entitlement}) {
  final info = MockCustomerInfo();
  final entitlements = MockEntitlementInfos();
  if (entitlement != null) {
    when(() => entitlements.active).thenReturn({kRCEntitlementId: entitlement});
  } else {
    when(() => entitlements.active).thenReturn({});
  }
  when(() => info.entitlements).thenReturn(entitlements);
  return info;
}

class MockEntitlementInfos extends Mock implements EntitlementInfos {}

void main() {
  group('RevenueCatAdapter.fromCustomerInfo', () {
    test('returns isPro=false when no active PRO entitlement is present', () {
      final result = RevenueCatAdapter.fromCustomerInfo(_customerInfo());
      expect(result.isPro, isFalse);
      expect(result.source, 'unknown');
      expect(result.expiresAt, isNull);
    });

    test('returns isPro=true with app_store source for App Store entitlement',
        () {
      final result = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(
          entitlement: _entitlement(
            store: Store.appStore,
            expirationDate: '2026-12-31T00:00:00Z',
          ),
        ),
      );
      expect(result.isPro, isTrue);
      expect(result.source, 'app_store');
      expect(result.expiresAt, DateTime.parse('2026-12-31T00:00:00Z').toLocal());
    });

    test('macAppStore is also mapped to app_store', () {
      final result = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(entitlement: _entitlement(store: Store.macAppStore)),
      );
      expect(result.source, 'app_store');
    });

    test('playStore is mapped to play_store', () {
      final result = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(entitlement: _entitlement(store: Store.playStore)),
      );
      expect(result.source, 'play_store');
    });

    test('amazon store has its own mapping', () {
      final result = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(entitlement: _entitlement(store: Store.amazon)),
      );
      expect(result.source, 'amazon');
    });

    test('stripe and rcBilling are both mapped to stripe', () {
      final stripeResult = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(entitlement: _entitlement(store: Store.stripe)),
      );
      final rcBillingResult = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(entitlement: _entitlement(store: Store.rcBilling)),
      );
      expect(stripeResult.source, 'stripe');
      expect(rcBillingResult.source, 'stripe');
    });

    test('promotional is mapped to promotional', () {
      final result = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(entitlement: _entitlement(store: Store.promotional)),
      );
      expect(result.source, 'promotional');
    });

    test('storeTxId is always null (RC Flutter SDK does not expose it)', () {
      final result = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(entitlement: _entitlement(store: Store.appStore)),
      );
      expect(result.storeTxId, isNull);
    });

    test('expiresAt is null when entitlement does not provide one', () {
      final result = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(entitlement: _entitlement(store: Store.appStore)),
      );
      expect(result.expiresAt, isNull);
    });

    test('an unparseable expirationDate becomes null instead of throwing', () {
      final result = RevenueCatAdapter.fromCustomerInfo(
        _customerInfo(
          entitlement: _entitlement(
            store: Store.appStore,
            expirationDate: 'not-a-date',
          ),
        ),
      );
      expect(result.expiresAt, isNull);
    });
  });
}
