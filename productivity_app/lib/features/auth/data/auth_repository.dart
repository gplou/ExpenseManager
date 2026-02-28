import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/auth_repository_contract.dart';
import '../domain/user_model.dart';

class AuthRepository implements AuthRepositoryContract {
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
        throw const AuthFailure('No se pudo iniciar sesión');
      }
      return _mapUser(response.user!);
    } on AuthException catch (e) {
      throw AuthFailure(_mapAuthError(e.message));
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
        throw const AuthFailure('No se pudo crear la cuenta');
      }
      return _mapUser(response.user!);
    } on AuthException catch (e) {
      throw AuthFailure(_mapAuthError(e.message));
    } catch (e) {
      throw const UnexpectedFailure();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  UserModel _mapUser(User user) => UserModel(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['name'] as String?,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        isEmailVerified: user.emailConfirmedAt != null,
        createdAt: DateTime.parse(user.createdAt),
      );

  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Email o contraseña incorrectos';
    }
    if (message.contains('Email not confirmed')) {
      return 'Debes verificar tu email antes de iniciar sesión';
    }
    if (message.contains('User already registered')) {
      return 'Este email ya está registrado';
    }
    return message;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepositoryContract>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
