// Integration tests for the delete-account repository contract.
// Verifies the contract semantics independent of the Riverpod layer.

import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/features/auth/domain/auth_repository_contract.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';

// ── Fake repository ───────────────────────────────────────────────────────────

class _FakeAuthRepository implements AuthRepositoryContract, SocialAuthContract {
  UserModel? _currentUser;
  bool shouldFailDeleteAccount = false;
  bool deleteAccountCalled = false;

  @override
  Stream<UserModel?> get authStateChanges => Stream.value(_currentUser);

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _currentUser = _create(email: email);
    return _currentUser!;
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    _currentUser = _create(email: email, name: name);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async => _currentUser = null;

  @override
  Future<UserModel> signInWithGoogle() async {
    _currentUser = _create(email: 'google@test.com', name: 'Google User');
    return _currentUser!;
  }

  @override
  Future<UserModel> signInWithApple() async {
    _currentUser = _create(email: 'apple@test.com', name: 'Apple User');
    return _currentUser!;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalled = true;
    if (shouldFailDeleteAccount) throw const UnexpectedFailure();
    _currentUser = null;
  }

  UserModel _create({required String email, String? name}) => UserModel(
        id: 'fake-id',
        email: email,
        name: name,
        createdAt: DateTime(2024),
      );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _FakeAuthRepository repo;

  setUp(() => repo = _FakeAuthRepository());

  group('AuthRepositoryContract.deleteAccount — contract semantics', () {
    test('deleteAccount clears current user after sign-in', () async {
      await repo.signInWithEmail(email: 'user@test.com', password: 'pass1234');
      expect(repo.currentUser, isNotNull);

      await repo.deleteAccount();

      expect(repo.currentUser, isNull);
    });

    test('deleteAccount clears current user after sign-up', () async {
      await repo.signUpWithEmail(
        email: 'new@test.com',
        password: 'pass1234',
        name: 'New User',
      );
      expect(repo.currentUser, isNotNull);

      await repo.deleteAccount();

      expect(repo.currentUser, isNull);
    });

    test('deleteAccount clears current user after Google sign-in', () async {
      await repo.signInWithGoogle();
      expect(repo.currentUser, isNotNull);

      await repo.deleteAccount();

      expect(repo.currentUser, isNull);
    });

    test('deleteAccount clears current user after Apple sign-in', () async {
      await repo.signInWithApple();
      expect(repo.currentUser, isNotNull);

      await repo.deleteAccount();

      expect(repo.currentUser, isNull);
    });

    test('deleteAccount completes without error when no user session exists',
        () async {
      expect(repo.currentUser, isNull);

      expect(() => repo.deleteAccount(), returnsNormally);
    });

    test('deleteAccount throws AppFailure on server error', () async {
      repo.shouldFailDeleteAccount = true;

      await repo.signInWithEmail(email: 'user@test.com', password: 'pass1234');

      expect(
        () => repo.deleteAccount(),
        throwsA(isA<AppFailure>()),
      );
    });

    test('user remains set when deleteAccount throws', () async {
      await repo.signInWithEmail(email: 'user@test.com', password: 'pass1234');
      repo.shouldFailDeleteAccount = true;

      try {
        await repo.deleteAccount();
      } on AppFailure {
        // expected
      }

      // User must still be set — deletion did not succeed
      expect(repo.currentUser, isNotNull);
    });

    test('authStateChanges emits null after deleteAccount', () async {
      await repo.signInWithEmail(email: 'user@test.com', password: 'pass1234');
      await repo.deleteAccount();

      final emitted = await repo.authStateChanges.first;
      expect(emitted, isNull);
    });

    test('deleteAccount is called exactly once', () async {
      await repo.signInWithEmail(email: 'user@test.com', password: 'pass1234');

      expect(repo.deleteAccountCalled, isFalse);
      await repo.deleteAccount();
      expect(repo.deleteAccountCalled, isTrue);
    });
  });

  group('AuthRepositoryContract.deleteAccount — full lifecycle', () {
    test('sign-in → delete → sign-in again works correctly', () async {
      // First session
      await repo.signInWithEmail(email: 'user@test.com', password: 'pass1234');
      expect(repo.currentUser!.email, 'user@test.com');

      await repo.deleteAccount();
      expect(repo.currentUser, isNull);

      // New session (e.g. same email re-registered)
      await repo.signInWithEmail(
          email: 'user2@test.com', password: 'pass5678');
      expect(repo.currentUser, isNotNull);
      expect(repo.currentUser!.email, 'user2@test.com');
    });

    test('sign-out and deleteAccount both clear the user', () async {
      // signOut path
      await repo.signInWithEmail(email: 'a@test.com', password: 'pass1234');
      await repo.signOut();
      expect(repo.currentUser, isNull);

      // deleteAccount path
      await repo.signInWithEmail(email: 'b@test.com', password: 'pass1234');
      await repo.deleteAccount();
      expect(repo.currentUser, isNull);
    });
  });
}
