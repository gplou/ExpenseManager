import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:expense_manager/features/subscription/domain/subscription_repository_contract.dart';
import 'package:expense_manager/features/subscription/subscription_repository.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepositoryContract {}

void main() {
  // ── RCPurchaseResult ─────────────────────────────────────────────────────

  group('RCPurchaseResult', () {
    test('isPro is true when entitlement is active', () {
      const result = RCPurchaseResult(
        isPro: true,
        source: 'app_store',
        expiresAt: null,
        storeTxId: 'tx_123',
      );
      expect(result.isPro, isTrue);
      expect(result.source, 'app_store');
      expect(result.storeTxId, 'tx_123');
    });

    test('isPro is false when no entitlement', () {
      const result = RCPurchaseResult(
        isPro: false,
        source: 'unknown',
      );
      expect(result.isPro, isFalse);
      expect(result.expiresAt, isNull);
      expect(result.storeTxId, isNull);
    });

    test('expiresAt is preserved when set', () {
      final expires = DateTime(2026, 12, 31);
      final result = RCPurchaseResult(
        isPro: true,
        source: 'google_play',
        expiresAt: expires,
      );
      expect(result.expiresAt, expires);
    });

    test('source correctly reflects play_store', () {
      const result = RCPurchaseResult(isPro: true, source: 'play_store');
      expect(result.source, 'play_store');
    });
  });

  // ── RCPurchaseException ──────────────────────────────────────────────────

  group('RCPurchaseException', () {
    test('has correct message', () {
      const ex = RCPurchaseException('Producto no disponible');
      expect(ex.message, 'Producto no disponible');
    });

    test('implements Exception', () {
      const ex = RCPurchaseException('error');
      expect(ex, isA<Exception>());
    });
  });

  // ── RCPurchaseCancelledException ─────────────────────────────────────────

  group('RCPurchaseCancelledException', () {
    test('can be instantiated', () {
      const ex = RCPurchaseCancelledException();
      expect(ex, isA<Exception>());
    });
  });

  // ── PromoResult ──────────────────────────────────────────────────────────

  group('PromoResult', () {
    test('isSubscription is true for subscription type', () {
      const result = PromoResult(type: 'subscription', durationDays: 30);
      expect(result.isSubscription, isTrue);
      expect(result.isDiscount, isFalse);
    });

    test('isDiscount is true for discount type', () {
      const result = PromoResult(
        type: 'discount',
        durationDays: 0,
        discountPercentage: 50,
      );
      expect(result.isDiscount, isTrue);
      expect(result.isSubscription, isFalse);
    });

    test('discountPercentage is null for subscription type by default', () {
      const result = PromoResult(type: 'subscription', durationDays: 30);
      expect(result.discountPercentage, isNull);
      expect(result.isSubscription, isTrue);
      expect(result.isDiscount, isFalse);
    });
  });

  // ── PromoCodeException ───────────────────────────────────────────────────

  group('PromoCodeException', () {
    test('has correct message', () {
      const ex = PromoCodeException('Codigo no valido');
      expect(ex.message, 'Codigo no valido');
    });

    test('implements Exception', () {
      const ex = PromoCodeException('err');
      expect(ex, isA<Exception>());
    });
  });

  // ── Mock repository contract ─────────────────────────────────────────────

  group('SubscriptionRepositoryContract mock', () {
    late MockSubscriptionRepository mockRepo;

    setUp(() {
      mockRepo = MockSubscriptionRepository();
    });

    test('purchaseProPlan returns PRO result', () async {
      final expires = DateTime.now().add(const Duration(days: 31));
      when(() => mockRepo.purchaseProPlan()).thenAnswer(
        (_) async => RCPurchaseResult(
          isPro: true,
          source: 'google_play',
          expiresAt: expires,
          storeTxId: 'tx_abc',
        ),
      );

      final result = await mockRepo.purchaseProPlan();
      expect(result.isPro, isTrue);
      expect(result.source, 'google_play');
      expect(result.expiresAt, expires);
    });

    test('purchaseProPlan throws RCPurchaseCancelledException on cancel',
        () async {
      when(() => mockRepo.purchaseProPlan())
          .thenThrow(const RCPurchaseCancelledException());

      expect(
        () => mockRepo.purchaseProPlan(),
        throwsA(isA<RCPurchaseCancelledException>()),
      );
    });

    test('purchaseProPlan throws RCPurchaseException on error', () async {
      when(() => mockRepo.purchaseProPlan())
          .thenThrow(const RCPurchaseException('Network error'));

      expect(
        () => mockRepo.purchaseProPlan(),
        throwsA(
          isA<RCPurchaseException>()
              .having((e) => e.message, 'message', 'Network error'),
        ),
      );
    });

    test('restoreProPlan returns non-PRO when nothing to restore', () async {
      when(() => mockRepo.restoreProPlan()).thenAnswer(
        (_) async => const RCPurchaseResult(isPro: false, source: 'unknown'),
      );

      final result = await mockRepo.restoreProPlan();
      expect(result.isPro, isFalse);
    });

    test('getCurrentRCStatus returns null when RC unavailable', () async {
      when(() => mockRepo.getCurrentRCStatus()).thenAnswer((_) async => null);

      final result = await mockRepo.getCurrentRCStatus();
      expect(result, isNull);
    });

    test('getCurrentRCStatus returns PRO result when entitled', () async {
      final expires = DateTime.now().add(const Duration(days: 30));
      when(() => mockRepo.getCurrentRCStatus()).thenAnswer(
        (_) async => RCPurchaseResult(
          isPro: true,
          source: 'app_store',
          expiresAt: expires,
        ),
      );

      final result = await mockRepo.getCurrentRCStatus();
      expect(result, isNotNull);
      expect(result!.isPro, isTrue);
    });
  });
}
