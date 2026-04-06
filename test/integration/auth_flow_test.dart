import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/domain/auth_repository_contract.dart';

/// A fake implementation of AuthRepositoryContract for testing the auth flow.
class FakeAuthRepository implements AuthRepositoryContract, SocialAuthContract {
  UserModel? _currentUser;
  bool shouldFailSignIn = false;
  bool shouldFailSignUp = false;
  String failureMessage = 'Test error';

  @override
  Stream<UserModel?> get authStateChanges => Stream.value(_currentUser);

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldFailSignIn) throw AuthFailure(failureMessage);
    _currentUser = _createUser(email: email);
    return _currentUser!;
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    if (shouldFailSignUp) throw AuthFailure(failureMessage);
    _currentUser = _createUser(email: email, name: name);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    _currentUser = _createUser(email: 'google@test.com', name: 'Google User');
    return _currentUser!;
  }

  @override
  Future<UserModel> signInWithApple() async {
    _currentUser = _createUser(email: 'apple@test.com', name: 'Apple User');
    return _currentUser!;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  UserModel _createUser({required String email, String? name}) => UserModel(
        id: 'fake-id-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );
}

void main() {
  late FakeAuthRepository authRepo;

  setUp(() {
    authRepo = FakeAuthRepository();
  });

  group('Auth flow integration', () {
    test('sign in → current user is set → sign out → current user is null', () async {
      expect(authRepo.currentUser, isNull);

      await authRepo.signInWithEmail(email: 'test@test.com', password: 'pass1234');
      expect(authRepo.currentUser, isNotNull);
      expect(authRepo.currentUser!.email, 'test@test.com');

      await authRepo.signOut();
      expect(authRepo.currentUser, isNull);
    });

    test('sign up creates user with name', () async {
      final user = await authRepo.signUpWithEmail(
        email: 'new@test.com',
        password: 'pass1234',
        name: 'New User',
      );
      expect(user.email, 'new@test.com');
      expect(user.name, 'New User');
      expect(authRepo.currentUser, isNotNull);
    });

    test('failed sign in throws AuthFailure', () async {
      authRepo.shouldFailSignIn = true;
      authRepo.failureMessage = 'Email o contraseña incorrectos';

      expect(
        () => authRepo.signInWithEmail(email: 'bad@test.com', password: 'wrong'),
        throwsA(isA<AuthFailure>()),
      );
      expect(authRepo.currentUser, isNull);
    });

    test('failed sign up throws AuthFailure', () async {
      authRepo.shouldFailSignUp = true;
      authRepo.failureMessage = 'Este email ya está registrado';

      expect(
        () => authRepo.signUpWithEmail(email: 'dup@test.com', password: 'pass1234'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('Google sign in sets user', () async {
      await authRepo.signInWithGoogle();
      expect(authRepo.currentUser, isNotNull);
      expect(authRepo.currentUser!.email, 'google@test.com');
    });

    test('Apple sign in sets user', () async {
      await authRepo.signInWithApple();
      expect(authRepo.currentUser, isNotNull);
      expect(authRepo.currentUser!.email, 'apple@test.com');
    });

    test('sign out after social sign in clears user', () async {
      await authRepo.signInWithGoogle();
      expect(authRepo.currentUser, isNotNull);

      await authRepo.signOut();
      expect(authRepo.currentUser, isNull);
    });

    test('authStateChanges emits current user', () async {
      await authRepo.signInWithEmail(email: 'test@test.com', password: 'pass');
      final stream = authRepo.authStateChanges;
      final user = await stream.first;
      expect(user, isNotNull);
      expect(user!.email, 'test@test.com');
    });
  });
}
