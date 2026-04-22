import 'package:purchases_flutter/purchases_flutter.dart';

import '../subscription_repository.dart';

/// Converts RevenueCat SDK types to the app's internal domain types.
///
/// Centralises the mapping so any change to the RC entitlement structure
/// only needs to be updated here.
class RevenueCatAdapter {
  const RevenueCatAdapter._();

  /// Converts a [CustomerInfo] from the RC SDK into an [RCPurchaseResult].
  static RCPurchaseResult fromCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.active[kRCEntitlementId];
    if (entitlement == null) {
      return const RCPurchaseResult(isPro: false, source: 'unknown');
    }
    final source = _sourceFromStore(entitlement.store);
    return RCPurchaseResult(
      isPro: true,
      source: source,
      expiresAt: entitlement.expirationDate != null
          ? DateTime.tryParse(entitlement.expirationDate!)?.toLocal()
          : null,
      // The Flutter RC SDK does not expose a store transaction id on
      // EntitlementInfo. Leave null rather than writing the RC app-user id
      // into the `store_tx_id` column, which would corrupt that field.
      storeTxId: null,
    );
  }

  static String _sourceFromStore(Store store) => switch (store) {
        Store.appStore || Store.macAppStore => 'app_store',
        Store.playStore => 'play_store',
        Store.amazon => 'amazon',
        Store.stripe || Store.rcBilling => 'stripe',
        Store.promotional => 'promotional',
        _ => 'unknown',
      };
}
