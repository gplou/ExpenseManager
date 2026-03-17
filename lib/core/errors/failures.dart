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
  const ServerFailure([super.message = 'Error interno del servidor']);
}

/// Error de caché / almacenamiento local
final class CacheFailure extends AppFailure {
  const CacheFailure([super.message = 'Error al acceder al almacenamiento local']);
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
  const UnexpectedFailure([super.message = 'Ha ocurrido un error inesperado']);
}

/// Extensión para obtener mensajes amigables para el usuario
extension AppFailureExtension on AppFailure {
  String get userMessage => switch (this) {
        AuthFailure(message: final msg) => msg,
        NetworkFailure() => 'Sin conexión a internet. Revisa tu red.',
        ServerFailure() => 'El servidor no está disponible. Intenta más tarde.',
        CacheFailure() => 'Error al cargar datos locales.',
        ValidationFailure(message: final msg) => msg,
        RateLimitFailure(message: final msg) => msg,
        UnexpectedFailure() => 'Algo salió mal. Intenta de nuevo.',
      };
}
