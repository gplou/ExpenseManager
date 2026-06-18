import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/features/subscription/subscription_repository.dart';

import '../../helpers/mocks.dart';

/// Mapeo de errores del RPC `redeem_promo_code` (server-side) a las
/// excepciones que la UI ya maneja.
void main() {
  late MockSupabaseClient client;
  late SubscriptionRepository repo;

  setUp(() {
    client = MockSupabaseClient();
    repo = SubscriptionRepository(client, MockPurchasesGateway());
  });

  void stubRpcThrows(PostgrestException e) {
    when(() => client.rpc<dynamic>(
          'redeem_promo_code',
          params: any(named: 'params'),
        )).thenThrow(e);
  }

  group('redeemPromoCode — server-side rate limit', () {
    test('hint promo_rate_limited:<s> maps to PromoCooldownException', () async {
      stubRpcThrows(const PostgrestException(
        message: 'Demasiados intentos. Inténtalo más tarde.',
        code: 'P0001',
        hint: 'promo_rate_limited:1234',
      ));

      await expectLater(
        () => repo.redeemPromoCode('CODE'),
        throwsA(isA<PromoCooldownException>()
            .having((e) => e.remainingSeconds, 'remainingSeconds', 1234)),
      );
    });

    test('hint without seconds falls back to 3600', () async {
      stubRpcThrows(const PostgrestException(
        message: 'Demasiados intentos.',
        code: 'P0001',
        hint: 'promo_rate_limited',
      ));

      await expectLater(
        () => repo.redeemPromoCode('CODE'),
        throwsA(isA<PromoCooldownException>()
            .having((e) => e.remainingSeconds, 'remainingSeconds', 3600)),
      );
    });

    test('other P0001 errors still map to PromoCodeException', () async {
      stubRpcThrows(const PostgrestException(
        message: 'Código no válido',
        code: 'P0001',
      ));

      await expectLater(
        () => repo.redeemPromoCode('BAD'),
        throwsA(isA<PromoCodeException>()
            .having((e) => e.message, 'message', 'Código no válido')),
      );
    });
  });
}
