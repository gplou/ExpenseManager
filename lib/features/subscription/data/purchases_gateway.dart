import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Thin abstraction over RevenueCat's `Purchases.*` static API so the
/// subscription stack can be tested without the native SDK.
///
/// The default implementation [RevenueCatPurchasesGateway] delegates 1:1
/// to `Purchases.*`. In tests, override [purchasesGatewayProvider] with a
/// mock that implements only the methods exercised by the test.
abstract interface class PurchasesGateway {
  Future<CustomerInfo> getCustomerInfo();

  Future<CustomerInfo> purchasePackage(Package package);

  Future<CustomerInfo> restorePurchases();

  Future<Offerings> getOfferings();

  void logIn(String userId);

  void logOut();

  void addCustomerInfoUpdateListener(CustomerInfoUpdateListener listener);

  void removeCustomerInfoUpdateListener(CustomerInfoUpdateListener listener);
}

class RevenueCatPurchasesGateway implements PurchasesGateway {
  const RevenueCatPurchasesGateway();

  @override
  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  @override
  Future<CustomerInfo> purchasePackage(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  @override
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  @override
  Future<Offerings> getOfferings() => Purchases.getOfferings();

  /// Fire-and-forget: matches the existing call pattern in
  /// SubscriptionNotifier where logIn/logOut errors are intentionally
  /// swallowed (the RC identity is best-effort).
  @override
  void logIn(String userId) {
    Purchases.logIn(userId).ignore();
  }

  @override
  void logOut() {
    Purchases.logOut().ignore();
  }

  @override
  void addCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  @override
  void removeCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) {
    Purchases.removeCustomerInfoUpdateListener(listener);
  }
}

final purchasesGatewayProvider = Provider<PurchasesGateway>((ref) {
  return const RevenueCatPurchasesGateway();
});
