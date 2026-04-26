// Tests for AuthNotifier.deleteAccount() — state machine transitions and
// error handling through the Riverpod notifier.

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
  bool failDeleteAccount = false;

  @override
  Stream<UserModel?> get authStateChanges => Stream.value(_user);

  @override
  UserModel? get currentUser => _user;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _user = _make(email);
    return _user!;
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    _user = _make(email, name: name);
    return _user!;
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<UserModel> signInWithGoogle() async {
    _user = _make('google@test.com');
    return _user!;
  }

  @override
  Future<UserModel> signInWithApple() async {
    _user = _make('apple@test.com');
    return _user!;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<void> deleteAccount() async {
    if (failDeleteAccount) throw const UnexpectedFailure();
    _user = null;
  }

  UserModel _make(String email, {String? name}) => UserModel(
        id: 'test-id',
        email: email,
        name: name,
        createdAt: DateTime(2024),
      );
}

// ── Container helper ──────────────────────────────────────────────────────────

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

  group('AuthNotifier.deleteAccount — success path', () {
    test('returns true when deletion succeeds', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      // Sign in first so there is a user session
      await container
          .read(authProvider.notifier)
          .signIn(email: 'user@test.com', password: 'pass1234');

      final result =
          await container.read(authProvider.notifier).deleteAccount();

      expect(result, isTrue);
    });

    test('state returns to Idle after successful deletion', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn(email: 'user@test.com', password: 'pass1234');

      await container.read(authProvider.notifier).deleteAccount();

      expect(container.read(authProvider), isA<Idle>());
    });

    test('repository user is null after deletion', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn(email: 'user@test.com', password: 'pass1234');
      expect(repo.currentUser, isNotNull);

      await container.read(authProvider.notifier).deleteAccount();

      expect(repo.currentUser, isNull);
    });

    test('can delete account without having signed in via notifier', () async {
      // Simulates a session restored on app start (user already set directly)
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result =
          await container.read(authProvider.notifier).deleteAccount();

      expect(result, isTrue);
      expect(repo.currentUser, isNull);
    });
  });

  group('AuthNotifier.deleteAccount — failure path', () {
    test('returns false when repository throws', () async {
      repo.failDeleteAccount = true;
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result =
          await container.read(authProvider.notifier).deleteAccount();

      expect(result, isFalse);
    });

    test('state transitions to Failure when repository throws', () async {
      repo.failDeleteAccount = true;
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).deleteAccount();

      expect(container.read(authProvider), isA<Failure>());
    });

    test('Failure contains the underlying AppFailure', () async {
      repo.failDeleteAccount = true;
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).deleteAccount();

      final state = container.read(authProvider);
      expect((state as Failure).failure, isA<AppFailure>());
    });

    test('user is NOT cleared on failure', () async {
      repo.failDeleteAccount = true;
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      // Sign in so a user exists
      await container
          .read(authProvider.notifier)
          .signIn(email: 'user@test.com', password: 'pass1234');

      await container.read(authProvider.notifier).deleteAccount();

      // Repo user should still be set because deletion failed
      expect(repo.currentUser, isNotNull);
    });

    test('reset() after failure returns to Idle', () async {
      repo.failDeleteAccount = true;
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).deleteAccount();
      expect(container.read(authProvider), isA<Failure>());

      container.read(authProvider.notifier).reset();
      expect(container.read(authProvider), isA<Idle>());
    });
  });

  group('AuthNotifier.deleteAccount — interaction with other actions', () {
    test('sign in then delete clears the user', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn(email: 'user@test.com', password: 'pass1234');
      expect(repo.currentUser, isNotNull);

      await container.read(authProvider.notifier).deleteAccount();
      expect(repo.currentUser, isNull);
    });

    test('sign up then delete clears the user', () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signUp(
            email: 'new@test.com',
            password: 'pass1234',
            name: 'New User',
          );
      expect(repo.currentUser, isNotNull);

      await container.read(authProvider.notifier).deleteAccount();
      expect(repo.currentUser, isNull);
    });

    test('state is Idle (not Success) after delete — prevents double redirect',
        () async {
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn(email: 'user@test.com', password: 'pass1234');
      expect(container.read(authProvider), isA<Success>());

      await container.read(authProvider.notifier).deleteAccount();
      expect(container.read(authProvider), isA<Idle>());
      expect(container.read(authProvider), isNot(isA<Success>()));
    });
  });
}
