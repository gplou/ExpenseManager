import 'package:expense_manager/features/auth/domain/user_model.dart';

/// Core authentication operations.
abstract interface class AuthRepositoryContract {
  /// Stream of the current user. Emits null when no session is active.
  Stream<UserModel?> get authStateChanges;

  /// Currently authenticated user (may be null).
  UserModel? get currentUser;

  /// Sign in with email and password.
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  /// Register a new user.
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  });

  /// Sign out.
  Future<void> signOut();

  /// Send password reset email.
  Future<void> sendPasswordReset({required String email});

  /// Delete the current user's account and all associated data.
  Future<void> deleteAccount();
}

/// Social authentication operations (platform-dependent).
abstract interface class SocialAuthContract {
  /// Sign in (or register) with Google.
  Future<UserModel> signInWithGoogle();

  /// Sign in (or register) with Apple. iOS/macOS only.
  Future<UserModel> signInWithApple();
}
