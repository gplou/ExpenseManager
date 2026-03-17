/// Immutable state for the PRO subscription.
///
/// [isPro] is a derived getter: true when [expiresAt] is in the future.
class SubscriptionState {
  const SubscriptionState({
    this.expiresAt,
    this.isLoading = false,
    this.purchaseError,
    this.source,
    this.pendingDiscountPercentage,
  });

  final DateTime? expiresAt;
  final bool isLoading;
  final String? purchaseError;

  /// 'google_play' | 'app_store' | 'promo_code'
  final String? source;

  /// Discount percentage (1-100) from a redeemed 'discount' promo code.
  /// When set, the user must complete a store purchase to activate PRO.
  /// Bonus days = (31 * discountPercentage / 100) are added after purchase.
  final int? pendingDiscountPercentage;

  bool get isPro =>
      expiresAt != null && expiresAt!.isAfter(DateTime.now());

  /// Whether the user has a pending discount that requires a store purchase.
  bool get hasDiscount => pendingDiscountPercentage != null;

  /// Bonus days granted when completing a purchase with a pending discount.
  int get discountBonusDays =>
      pendingDiscountPercentage != null
          ? (31 * pendingDiscountPercentage! / 100).round()
          : 0;

  SubscriptionState copyWith({
    DateTime? expiresAt,
    bool clearExpiry = false,
    bool? isLoading,
    String? purchaseError,
    bool clearError = false,
    String? source,
    int? pendingDiscountPercentage,
    bool clearDiscount = false,
  }) {
    return SubscriptionState(
      expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
      isLoading: isLoading ?? this.isLoading,
      purchaseError: clearError ? null : (purchaseError ?? this.purchaseError),
      source: source ?? this.source,
      pendingDiscountPercentage: clearDiscount
          ? null
          : (pendingDiscountPercentage ?? this.pendingDiscountPercentage),
    );
  }
}
