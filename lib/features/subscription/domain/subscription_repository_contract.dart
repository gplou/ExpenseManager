import 'package:in_app_purchase/in_app_purchase.dart';

import '../subscription_repository.dart';

/// Contract for subscription data operations.
abstract class SubscriptionRepositoryContract {
  Future<({DateTime? expiresAt, String? source})> fetchRemoteSubscription();

  Future<void> upsertSubscription({
    required DateTime expiresAt,
    required String source,
    String? storeTxId,
  });

  Future<bool> checkTrialUsed();

  Future<DateTime> startFreeTrial();

  Future<PromoResult> redeemPromoCode(String code);

  Future<ProductDetails?> loadProduct(String productId);

  Stream<List<PurchaseDetails>> get purchaseStream;
}
