import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/features/auth/data/auth_repository.dart';
import 'package:expense_manager/features/auth/domain/auth_repository_contract.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeAuthRepo implements AuthRepositoryContract, SocialAuthContract {
  UserModel? _user;
  bool failSignIn = false;
  bool failSignUp = false;
  bool failGoogle = false;
  String errorMsg = 'Error de prueba';

  @override
  Stream<UserModel?> get authStateChanges => Stream.value(_user);

  @override
  UserModel? get currentUser => _user;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (failSignIn) throw AuthFailure(errorMsg);
    _user = _make(email);
    return _user!;
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    if (failSignUp) throw AuthFailure(errorMsg);
    _user = _make(email, name: name);
    return _user!;
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<UserModel> signInWithGoogle() async {
    if (failGoogle) throw AuthFailure(errorMsg);
    _user = _make('google@test.com', name: 'Google User');
    return _user!;
  }

  @override
  Future<UserModel> signInWithApple() async {
    _user = _make('apple@test.com', name: 'Apple User');
    return _user!;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  bool failDeleteAccount = false;

  @override
  Future<void> deleteAccount() async {
    if (failDeleteAccount) throw const UnexpectedFailure();
    _user = null;
  }

  UserModel _make(String email, {String? name}) => UserModel(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );
}

// ── Helper ────────────────────────────────────────────────────────────────────

ProviderContainer _makeContainer(_FakeAuthRepo repo) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWith((ref) => repo),
      socialAuthProvider.overrideWith((ref) => repo),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _FakeAuthRepo repo;

  setUp(() => repo = _FakeAuthRepo());

  group('AuthNotifier initial state', () {
    test('starts as Idle', () {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      expect(container.read(authProvider), isA<Idle>());
    });
  });

  group('AuthNotifier.signIn', () {
    test('returns true and transitions to Success on valid credentials', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(authProvider.notifier)
          .signIn(email: 'user@test.com', password: 'pass1234');

      expect(result, isTrue);
      expect(container.read(authProvider), isA<Success>());
    });

    test('returns false and transitions to Failure on bad credentials', () async {
      repo.failSignIn = true;
      repo.errorMsg = 'Email o contraseña incorrectos';

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(authProvider.notifier)
          .signIn(email: 'bad@test.com', password: 'wrong');

      expect(result, isFalse);
      final state = container.read(authProvider);
      expect(state, isA<Failure>());
      expect((state as Failure).failure, isA<AuthFailure>());
      expect((state.failure as AuthFailure).message, 'Email o contraseña incorrectos');
    });
  });

  group('AuthNotifier.signUp', () {
    test('returns true and transitions to Success', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(authProvider.notifier)
          .signUp(email: 'new@test.com', password: 'pass1234', name: 'Test');

      expect(result, isTrue);
      expect(container.read(authProvider), isA<Success>());
    });

    test('returns false and transitions to Failure on duplicate email', () async {
      repo.failSignUp = true;
      repo.errorMsg = 'Este email ya está registrado';

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(authProvider.notifier)
          .signUp(email: 'dup@test.com', password: 'pass1234');

      expect(result, isFalse);
      final state = container.read(authProvider);
      expect(state, isA<Failure>());
    });
  });

  group('AuthNotifier.signInWithGoogle', () {
    test('returns true and transitions to Success', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(authProvider.notifier)
          .signInWithGoogle();

      expect(result, isTrue);
      expect(container.read(authProvider), isA<Success>());
    });

    test('returns false and transitions to Failure when Google fails', () async {
      repo.failGoogle = true;

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(authProvider.notifier)
          .signInWithGoogle();

      expect(result, isFalse);
      expect(container.read(authProvider), isA<Failure>());
    });
  });

  group('AuthNotifier.signInWithApple', () {
    test('returns true and transitions to Success', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(authProvider.notifier)
          .signInWithApple();

      expect(result, isTrue);
      expect(container.read(authProvider), isA<Success>());
    });
  });

  group('AuthNotifier.signOut', () {
    test('transitions back to Idle after sign in', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn(email: 'user@test.com', password: 'pass1234');
      expect(container.read(authProvider), isA<Success>());

      await container.read(authProvider.notifier).signOut();
      expect(container.read(authProvider), isA<Idle>());
    });
  });

  group('AuthNotifier.reset', () {
    test('resets Failure state back to Idle', () async {
      repo.failSignIn = true;

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn(email: 'bad@test.com', password: 'wrong');
      expect(container.read(authProvider), isA<Failure>());

      container.read(authProvider.notifier).reset();
      expect(container.read(authProvider), isA<Idle>());
    });

    test('resets Success state back to Idle', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn(email: 'user@test.com', password: 'pass1234');
      expect(container.read(authProvider), isA<Success>());

      container.read(authProvider.notifier).reset();
      expect(container.read(authProvider), isA<Idle>());
    });
  });
}
