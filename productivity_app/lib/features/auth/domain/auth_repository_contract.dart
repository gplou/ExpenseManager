import '../domain/user_model.dart';

/// Contrato del repositorio de autenticación.
/// 
/// La capa de presentación depende SOLO de esta abstracción,
/// nunca de la implementación concreta. Esto facilita el testeo.
abstract interface class AuthRepositoryContract {
  /// Stream del usuario actual. Emite null cuando no hay sesión activa.
  Stream<UserModel?> get authStateChanges;

  /// Usuario actualmente autenticado (puede ser null).
  UserModel? get currentUser;

  /// Inicia sesión con email y contraseña.
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  /// Registra un nuevo usuario.
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  });

  /// Cierra la sesión actual.
  Future<void> signOut();

  /// Envía email para resetear contraseña.
  Future<void> sendPasswordReset({required String email});
}
