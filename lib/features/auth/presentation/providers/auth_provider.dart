import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/analytics_service.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';
import '../../../subscription/subscription_provider.dart';

part 'auth_provider.g.dart';

/// Estado del stream de autenticación.
/// Escucha cambios en tiempo real (login, logout, token refresh).
@riverpod
Stream<UserModel?> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

/// Usuario actual (sincrónico, puede ser null).
/// Escucha [authStateProvider] para reconstruirse en cada cambio de auth
/// (login, logout, token refresh, restauración de sesión).
@riverpod
UserModel? currentUser(CurrentUserRef ref) {
  return ref.watch(authStateProvider).valueOrNull
      ?? ref.watch(authRepositoryProvider).currentUser;
}

/// Devuelve true si el usuario inició sesión con email y contraseña.
/// Los usuarios de Google/Apple tienen provider distinto a 'email'.
@riverpod
bool isEmailPasswordUser(IsEmailPasswordUserRef ref) {
  // Re-ejecutar cuando cambie el estado de auth
  ref.watch(authStateProvider);
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) return false;
  final provider = user.appMetadata['provider'] as String?;
  return provider == 'email';
}

// ── Notifier para acciones de Auth ───────────────────────────────────────────

sealed class AuthAction {}
final class Idle extends AuthAction {}
final class Loading extends AuthAction {}
final class Success extends AuthAction {}
final class Failure extends AuthAction {
  final AppFailure failure;
  Failure(this.failure);
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthAction build() => Idle();

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = Loading();
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
            email: email,
            password: password,
          );
      _identifyCurrentUser();
      state = Success();
      return true;
    } on AppFailure catch (e) {
      state = Failure(e);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    state = Loading();
    try {
      await ref.read(authRepositoryProvider).signUpWithEmail(
            email: email,
            password: password,
            name: name,
          );
      _identifyCurrentUser();
      state = Success();
      return true;
    } on AppFailure catch (e) {
      state = Failure(e);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = Loading();
    try {
      await ref.read(socialAuthProvider).signInWithGoogle();
      _identifyCurrentUser();
      state = Success();
      return true;
    } on AppFailure catch (e) {
      state = Failure(e);
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    state = Loading();
    try {
      await ref.read(socialAuthProvider).signInWithApple();
      _identifyCurrentUser();
      state = Success();
      return true;
    } on AppFailure catch (e) {
      state = Failure(e);
      return false;
    }
  }

  Future<void> signOut() async {
    Purchases.logOut().ignore();
    AnalyticsService.reset();
    await ref.read(authRepositoryProvider).signOut();
    state = Idle();
  }

  Future<bool> deleteAccount() async {
    state = Loading();
    try {
      Purchases.logOut().ignore();
      AnalyticsService.reset();
      await ref.read(authRepositoryProvider).deleteAccount();
      state = Idle();
      return true;
    } on AppFailure catch (e) {
      state = Failure(e);
      return false;
    }
  }

  void reset() => state = Idle();

  void _identifyCurrentUser() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      Purchases.logIn(user.id).ignore();
      AnalyticsService.identify(user.id, isPro: ref.read(isProProvider));
    }
  }
}
