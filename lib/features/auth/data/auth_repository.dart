import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';
import '../../../core/local_db/local_database.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/auth_repository_contract.dart';
import '../domain/user_model.dart';

class AuthRepository implements AuthRepositoryContract, SocialAuthContract {
  final SupabaseClient _client;

  AuthRepository(this._client);

  @override
  Stream<UserModel?> get authStateChanges => _client.auth.onAuthStateChange.map(
        (event) => event.session?.user != null
            ? _mapUser(event.session!.user)
            : null,
      );

  @override
  UserModel? get currentUser {
    final user = _client.auth.currentUser;
    return user != null ? _mapUser(user) : null;
  }

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const AuthFailure(
          'Sign-in returned a null user',
          code: AuthErrorCode.signInFailed,
        );
      }
      return _mapUser(response.user!);
    } on AppFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: _mapAuthError(e.message));
    } catch (e) {
      throw const UnexpectedFailure();
    }
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );
      if (response.user == null) {
        throw const AuthFailure(
          'Sign-up returned a null user',
          code: AuthErrorCode.signUpFailed,
        );
      }
      return _mapUser(response.user!);
    } on AppFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: _mapAuthError(e.message));
    } catch (e) {
      throw const UnexpectedFailure();
    }
  }

  @override
  Future<void> signOut() async {
    final userId = _client.auth.currentUser?.id;
    try {
      await _client.auth.signOut();
    } on AuthException catch (_) {
      // signOut failures are non-critical — the session is cleared locally
      // regardless, so swallow the error silently.
    } finally {
      // Clear local SQLite data so no sensitive records persist on shared devices.
      // Mirrors the cleanup that deleteAccount() already performs.
      if (userId != null) {
        await LocalDatabase.instance.clearUserData(userId);
      }
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    return _signInWithGoogleNative();
  }

  /// Flujo nativo con google_sign_in (iOS, Android, macOS).
  /// En iOS/macOS se pasa un nonce hasheado al SDK para que lo embeba en el
  /// idToken; Supabase verifica con el nonce raw — mismo patrón que Apple.
  Future<UserModel> _signInWithGoogleNative() async {
    try {
      if (AppConfig.googleWebClientId.isEmpty) {
        throw const AuthFailure(
          'Missing GOOGLE_WEB_CLIENT_ID in AppConfig.',
          code: AuthErrorCode.googleFailed,
        );
      }

      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId,
      );
      await GoogleSignIn.instance.signOut();
      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure(
          'Google idToken null: verify GOOGLE_WEB_CLIENT_ID is the Web Client '
          'ID (not the Android/iOS one) from Google Cloud Console.',
          code: AuthErrorCode.googleFailed,
        );
      }
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(const ['email', 'profile']);
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization?.accessToken,
      );
      if (response.user == null) {
        throw const AuthFailure(
          'Google sign-in returned a null user',
          code: AuthErrorCode.googleFailed,
        );
      }
      return _mapUser(response.user!);
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      debugPrint('[GoogleSignIn] AuthException: ${e.message} | statusCode: ${e.statusCode}');
      throw AuthFailure(e.message, code: _mapAuthError(e.message));
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') {
        throw const AuthFailure(
          'Google sign-in cancelled',
          code: AuthErrorCode.cancelled,
        );
      }
      if (e.code == 'network_error') {
        throw const AuthFailure(
          'Network error during Google sign-in',
          code: AuthErrorCode.noConnection,
        );
      }
      throw AuthFailure(
        'Google PlatformException [${e.code}]: ${e.message}',
        code: AuthErrorCode.googleFailed,
      );
    } catch (e) {
      debugPrint('[GoogleSignIn] unexpected error: $e');
      throw AuthFailure(
        'Unexpected Google sign-in error: $e',
        code: AuthErrorCode.googleFailed,
      );
    }
  }

  @override
  Future<UserModel> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthFailure(
          'Apple identityToken was null',
          code: AuthErrorCode.appleFailed,
        );
      }
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      if (response.user == null) {
        throw const AuthFailure(
          'Apple sign-in returned a null user',
          code: AuthErrorCode.appleFailed,
        );
      }
      return _mapUser(response.user!);
    } on AuthFailure {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthFailure(
          'Apple sign-in cancelled',
          code: AuthErrorCode.cancelled,
        );
      }
      throw AuthFailure(e.message, code: AuthErrorCode.appleFailed);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: _mapAuthError(e.message));
    } catch (e) {
      throw const UnexpectedFailure();
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: _mapAuthError(e.message));
    }
  }

  @override
  Future<void> deleteAccount() async {
    final userId = _client.auth.currentUser?.id;
    try {
      // 1. Borra datos remotos + cuenta en Supabase
      await _client.rpc<dynamic>('delete_user_account');
      // 2. Borra datos locales del usuario (otros usuarios no se ven afectados)
      if (userId != null) {
        await LocalDatabase.instance.clearUserData(userId);
      }
      // 3. Limpia la sesión local → dispara authStateChanges → router redirige al login
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: _mapAuthError(e.message));
    } catch (e) {
      throw const UnexpectedFailure();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  UserModel _mapUser(User user) => UserModel(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['name'] as String?
            ?? user.userMetadata?['full_name'] as String?,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        isEmailVerified: user.emailConfirmedAt != null,
        createdAt: DateTime.parse(user.createdAt),
      );

  /// Maps a raw Supabase auth error message to a stable [AuthErrorCode].
  /// The presentation layer turns the code into a localized message; the raw
  /// message is never shown to the user.
  AuthErrorCode _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return AuthErrorCode.invalidCredentials;
    }
    if (message.contains('Email not confirmed')) {
      return AuthErrorCode.emailNotConfirmed;
    }
    if (message.contains('User already registered')) {
      return AuthErrorCode.emailAlreadyRegistered;
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return AuthErrorCode.rateLimit;
    }
    return AuthErrorCode.generic;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Single shared instance — avoids creating two AuthRepository objects.
final _authRepositoryInstance = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepositoryContract>((ref) {
  return ref.watch(_authRepositoryInstance);
});

final socialAuthProvider = Provider<SocialAuthContract>((ref) {
  return ref.watch(_authRepositoryInstance);
});
