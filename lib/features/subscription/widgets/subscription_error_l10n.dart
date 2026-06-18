
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';

/// Maps a [SubscriptionErrorCode] to a localized, user-facing message.
String subscriptionErrorMessage(
  AppLocalizations l10n,
  SubscriptionErrorCode code,
) =>
    switch (code) {
      SubscriptionErrorCode.purchaseFailed => l10n.errorPurchaseGeneric,
      SubscriptionErrorCode.restoreFailed => l10n.errorRestoreGeneric,
      SubscriptionErrorCode.trialFailed => l10n.errorFreeTrialFailed,
    };
