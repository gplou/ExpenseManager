/// Immutable state for the PRO subscription.
///
/// [isPro] is a derived getter: true when [expiresAt] is in the future.
class SubscriptionState {
  const SubscriptionState({
    this.expiresAt,
    this.isLoading = false,
    this.purchaseError,
    this.source,
  });

  final DateTime? expiresAt;
  final bool isLoading;
  final String? purchaseError;

  /// 'google_play' | 'app_store' | 'promo_code'
  final String? source;

  bool get isPro =>
      expiresAt != null && expiresAt!.isAfter(DateTime.now());

  SubscriptionState copyWith({
    DateTime? expiresAt,
    bool clearExpiry = false,
    bool? isLoading,
    String? purchaseError,
    bool clearError = false,
    String? source,
  }) {
    return SubscriptionState(
      expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
      isLoading: isLoading ?? this.isLoading,
      purchaseError: clearError ? null : (purchaseError ?? this.purchaseError),
      source: source ?? this.source,
    );
  }
}
