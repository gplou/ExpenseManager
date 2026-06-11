import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/features/auth/data/auth_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

import '../../../helpers/local_db_helper.dart';
import '../../../helpers/mocks.dart';

User _userFixture({
  String id = 'user-1',
  String email = 'test@example.com',
  String? name,
  String? avatarUrl,
  String? emailConfirmedAt,
}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: {
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    },
    aud: 'authenticated',
    email: email,
    emailConfirmedAt: emailConfirmedAt,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

AuthResponse _authResponseWith(User? user) {
  return AuthResponse(
    user: user,
    session: user == null
        ? null
        : Session(
            accessToken: 'tok',
            tokenType: 'bearer',
            user: user,
          ),
  );
}

void main() {
  setUpAll(registerCommonFallbacks);

  late MockSupabaseClient supabase;
  late MockGoTrueClient auth;
  late AuthRepository repo;

  setUp(() async {
    await useInMemoryDatabase();
    supabase = MockSupabaseClient();
    auth = MockGoTrueClient();
    when(() => supabase.auth).thenReturn(auth);
    repo = AuthRepository(supabase);
  });

  // ── currentUser / authStateChanges ───────────────────────────────────────

  group('currentUser', () {
    test('returns null when there is no active session', () {
      when(() => auth.currentUser).thenReturn(null);
      expect(repo.currentUser, isNull);
    });

    test('maps Supabase user metadata into UserModel', () {
      when(() => auth.currentUser).thenReturn(
        _userFixture(
          id: 'u-42',
          email: 'g@x.com',
          name: 'Guille',
          avatarUrl: 'https://example.com/a.png',
          emailConfirmedAt: '2026-01-02T00:00:00Z',
        ),
      );

      final user = repo.currentUser!;
      expect(user.id, 'u-42');
      expect(user.email, 'g@x.com');
      expect(user.name, 'Guille');
      expect(user.avatarUrl, 'https://example.com/a.png');
      expect(user.isEmailVerified, isTrue);
    });

    test('falls back to full_name when name is missing', () {
      when(() => auth.currentUser).thenReturn(
        User(
          id: 'u-1',
          appMetadata: const {},
          userMetadata: const {'full_name': 'Full Name'},
          aud: 'authenticated',
          email: 'a@b.com',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );
      expect(repo.currentUser!.name, 'Full Name');
    });
  });

  // ── signInWithEmail ──────────────────────────────────────────────────────

  group('signInWithEmail', () {
    test('returns UserModel on success', () async {
      when(() => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
        (_) async => _authResponseWith(_userFixture(email: 'a@b.com')),
      );

      final result = await repo.signInWithEmail(
        email: 'a@b.com',
        password: 'pw',
      );
      expect(result.email, 'a@b.com');
    });

    test('throws AuthFailure when Supabase returns null user', () async {
      when(() => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => _authResponseWith(null));

      await expectLater(
        () => repo.signInWithEmail(email: 'a@b.com', password: 'pw'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('maps Invalid login credentials to invalidCredentials code', () async {
      when(() => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AuthException('Invalid login credentials'));

      await expectLater(
        () => repo.signInWithEmail(email: 'a@b.com', password: 'wrong'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthErrorCode.invalidCredentials,
          ),
        ),
      );
    });

    test('maps rate-limit errors to the rateLimit code', () async {
      when(() => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AuthException('over rate limit reached'));

      await expectLater(
        () => repo.signInWithEmail(email: 'a@b.com', password: 'p'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthErrorCode.rateLimit,
          ),
        ),
      );
    });

    test('unknown server errors map to the generic code (no leak to UI)',
        () async {
      // The raw message is kept on the failure for logging, but the UI maps
      // the *code* (generic) to a localized string — the raw text is never shown.
      when(() => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AuthException('internal db connection refused, host=...'));

      await expectLater(
        () => repo.signInWithEmail(email: 'a@b.com', password: 'p'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthErrorCode.generic,
          ),
        ),
      );
    });

    test('wraps unexpected exceptions as UnexpectedFailure', () async {
      when(() => auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(StateError('boom'));

      await expectLater(
        () => repo.signInWithEmail(email: 'a@b.com', password: 'p'),
        throwsA(isA<UnexpectedFailure>()),
      );
    });
  });

  // ── signUpWithEmail ──────────────────────────────────────────────────────

  group('signUpWithEmail', () {
    test('returns UserModel on success', () async {
      when(() => auth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => _authResponseWith(
          _userFixture(email: 'new@x.com', name: 'New'),
        ),
      );

      final result = await repo.signUpWithEmail(
        email: 'new@x.com',
        password: 'pw',
        name: 'New',
      );

      expect(result.email, 'new@x.com');
      expect(result.name, 'New');
    });

    test('maps User already registered to emailAlreadyRegistered code', () async {
      when(() => auth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          )).thenThrow(AuthException('User already registered'));

      await expectLater(
        () => repo.signUpWithEmail(email: 'x@x.com', password: 'p'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthErrorCode.emailAlreadyRegistered,
          ),
        ),
      );
    });

    test('throws AuthFailure when Supabase returns null user', () async {
      when(() => auth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          )).thenAnswer((_) async => _authResponseWith(null));

      await expectLater(
        () => repo.signUpWithEmail(email: 'x@x.com', password: 'p'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  // ── signOut ──────────────────────────────────────────────────────────────

  group('signOut', () {
    test('calls Supabase signOut and PRESERVES local data', () async {
      when(() => auth.currentUser).thenReturn(_userFixture(id: 'u-1'));
      when(() => auth.signOut()).thenAnswer((_) async {});

      // Para usuarios FREE el SQLite local es su ÚNICA copia: el logout
      // no debe borrarla (solo deleteAccount lo hace).
      final local = LocalTransactionsRepository(userId: 'u-1');
      await local.createTransaction(
        TransactionModel(
          id: 'tx-keep',
          userId: 'u-1',
          amount: 12.5,
          type: TransactionType.expense,
          category: 'Comida',
          date: DateTime(2026, 1, 10),
          createdAt: DateTime(2026, 1, 10),
        ),
      );

      await repo.signOut();

      verify(() => auth.signOut()).called(1);
      final remaining = await local.getAllForUser();
      expect(
        remaining.map((t) => t.id),
        contains('tx-keep'),
        reason: 'Logout must NOT wipe local data — for FREE users it is '
            'their only copy.',
      );
    });

    test('swallows AuthException from Supabase', () async {
      when(() => auth.currentUser).thenReturn(_userFixture(id: 'u-1'));
      when(() => auth.signOut()).thenThrow(AuthException('network down'));

      // Should not throw despite the AuthException
      await expectLater(repo.signOut(), completes);
    });

    test('still completes when no current user is present', () async {
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.signOut()).thenAnswer((_) async {});

      await expectLater(repo.signOut(), completes);
    });
  });

  // ── sendPasswordReset ────────────────────────────────────────────────────

  group('sendPasswordReset', () {
    test('calls resetPasswordForEmail with the given email', () async {
      when(() => auth.resetPasswordForEmail(any())).thenAnswer((_) async {});

      await repo.sendPasswordReset(email: 'me@x.com');

      verify(() => auth.resetPasswordForEmail('me@x.com')).called(1);
    });

    test('wraps AuthException into AuthFailure', () async {
      when(() => auth.resetPasswordForEmail(any()))
          .thenThrow(AuthException('rate limit'));

      await expectLater(
        () => repo.sendPasswordReset(email: 'me@x.com'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  // ── deleteAccount ────────────────────────────────────────────────────────

  // deleteAccount happy path requires HTTP-layer mocking of `rpc()` because
  // SupabaseClient.rpc returns a PostgrestFilterBuilder (not a plain Future).
  // We only cover the error paths here; the full success path is exercised
  // by integration tests against a real Supabase instance.
  group('deleteAccount (error paths)', () {
    test('wraps AuthException into a localized AuthFailure', () async {
      when(() => auth.currentUser).thenReturn(_userFixture(id: 'u-1'));
      when(() => supabase.rpc<dynamic>(any())).thenThrow(AuthException('boom'));

      await expectLater(
        () => repo.deleteAccount(),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('wraps unexpected errors into UnexpectedFailure', () async {
      when(() => auth.currentUser).thenReturn(_userFixture(id: 'u-1'));
      when(() => supabase.rpc<dynamic>(any())).thenThrow(StateError('boom'));

      await expectLater(
        () => repo.deleteAccount(),
        throwsA(isA<UnexpectedFailure>()),
      );
    });
  });
}
