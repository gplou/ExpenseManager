import '../../l10n/app_localizations.dart';
import 'failures.dart';

/// Presentation-layer mapping from a sealed [AppFailure] to a localized,
/// user-facing message.
///
/// This is the single place that turns failure *types/codes* (set by the data
/// layer) into translated strings — repositories never bake user-facing copy.
/// Keep [AppFailure.userMessage] for logging/diagnostics only.
extension AppFailureL10n on AppFailure {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
        AuthFailure(:final code) => _authMessage(l10n, code),
        NetworkFailure() => l10n.errorNetwork,
        ServerFailure() => l10n.errorServer,
        CacheFailure() => l10n.errorCache,
        ValidationFailure() => l10n.errorValidation,
        RateLimitFailure() => l10n.errorRateLimit,
        UnexpectedFailure() => l10n.errorGeneric,
      };

  String _authMessage(AppLocalizations l10n, AuthErrorCode code) =>
      switch (code) {
        AuthErrorCode.invalidCredentials => l10n.errorAuthInvalidCredentials,
        AuthErrorCode.emailNotConfirmed => l10n.errorAuthEmailNotConfirmed,
        AuthErrorCode.emailAlreadyRegistered =>
          l10n.errorAuthEmailAlreadyRegistered,
        AuthErrorCode.rateLimit => l10n.errorAuthRateLimit,
        AuthErrorCode.cancelled => l10n.errorAuthCancelled,
        AuthErrorCode.noConnection => l10n.errorAuthNoConnection,
        AuthErrorCode.googleFailed => l10n.errorAuthGoogleFailed,
        AuthErrorCode.appleFailed => l10n.errorAuthAppleFailed,
        AuthErrorCode.signInFailed => l10n.errorAuthSignInFailed,
        AuthErrorCode.signUpFailed => l10n.errorAuthSignUpFailed,
        AuthErrorCode.generic => l10n.errorAuthGeneric,
      };
}
