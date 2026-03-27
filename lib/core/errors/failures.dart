/// Tipos de error centralizados para toda la app.
/// 
/// En lugar de lanzar excepciones crudas, usamos sealed classes
/// para que el compilador nos obligue a manejar todos los casos.
sealed class AppFailure {
  final String message;
  const AppFailure(this.message);

  @override
  String toString() => message;
}

/// Error de autenticación (credenciales, sesión expirada, etc.)
final class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

/// Error de red o API
final class NetworkFailure extends AppFailure {
  final int? statusCode;
  const NetworkFailure(super.message, {this.statusCode});
}

/// Error de servidor (5xx)
final class ServerFailure extends AppFailure {
  const ServerFailure([super.message = 'Internal server error']);
}

/// Error de caché / almacenamiento local
final class CacheFailure extends AppFailure {
  const CacheFailure([super.message = 'Failed to access local storage']);
}

/// Error de validación de datos
final class ValidationFailure extends AppFailure {
  final Map<String, String>? fieldErrors;
  const ValidationFailure(super.message, {this.fieldErrors});
}

/// Error de límite de uso (rate limit)
final class RateLimitFailure extends AppFailure {
  const RateLimitFailure(super.message);
}

/// Error inesperado
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred']);
}

/// Extension to get user-friendly error messages.
/// Uses error codes internally; presentation layer maps to localized strings.
extension AppFailureExtension on AppFailure {
  /// Returns a user-friendly message. Falls back to the raw message
  /// when localization is not available.
  String get userMessage => switch (this) {
        AuthFailure(message: final msg) => msg,
        NetworkFailure() => message,
        ServerFailure() => message,
        CacheFailure() => message,
        ValidationFailure(message: final msg) => msg,
        RateLimitFailure(message: final msg) => msg,
        UnexpectedFailure() => message,
      };
}
