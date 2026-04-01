import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/analytics_service.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';

part 'auth_provider.g.dart';

/// Estado del stream de autenticación.
/// Escucha cambios en tiempo real (login, logout, token refresh).
@riverpod
Stream<UserModel?> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

/// Usuario actual (sincrónico, puede ser null).
@riverpod
UserModel? currentUser(CurrentUserRef ref) {
  return ref.watch(authRepositoryProvider).currentUser;
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

  void reset() => state = Idle();

  void _identifyCurrentUser() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      AnalyticsService.identify(user.id);
    }
  }
}
