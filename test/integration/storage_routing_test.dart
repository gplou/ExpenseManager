/// Tests that [transactionsRepositoryProvider] and
/// [recurringTransactionsRepositoryProvider] return the correct concrete
/// implementation depending on the user's PRO status and sync state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:productivity_app/core/network/supabase_client.dart';
import 'package:productivity_app/features/auth/domain/user_model.dart';
import 'package:productivity_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:productivity_app/features/subscription/subscription_provider.dart';
import 'package:productivity_app/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:productivity_app/features/transactions/data/local_transactions_repository.dart';
import 'package:productivity_app/features/transactions/data/recurring_transactions_repository.dart';
import 'package:productivity_app/features/transactions/data/transactions_repository.dart';
import 'package:productivity_app/features/transactions/presentation/providers/sync_provider.dart';

import '../helpers/mocks.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

final _fakeUser = UserModel(
  id: 'user-abc',
  email: 'test@example.com',
  createdAt: DateTime(2024, 1, 1),
);

/// Fake SyncNotifier that returns a fixed [SyncState] without running any
/// migration logic, so routing tests are not affected by async side effects.
class _FakeSyncNotifier extends SyncNotifier {
  _FakeSyncNotifier(this._state);
  final SyncState _state;

  @override
  Future<SyncState> build() async => _state;
}

ProviderContainer _makeContainer({
  required bool isPro,
  UserModel? user,
  bool isSyncing = false,
}) {
  final mockSupabase = MockSupabaseClient();
  // The client must not throw when used to construct a repository.
  when(() => mockSupabase.auth).thenReturn(MockGoTrueClient());

  return ProviderContainer(
    overrides: [
      isProProvider.overrideWith((ref) => isPro),
      currentUserProvider.overrideWith((ref) => user),
      syncProvider.overrideWith(
          () => _FakeSyncNotifier(SyncState(
              status: isSyncing ? SyncStatus.syncing : SyncStatus.idle))),
      supabaseClientProvider.overrideWith((ref) => mockSupabase),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── transactionsRepositoryProvider ────────────────────────────────────────

  group('transactionsRepositoryProvider', () {
    test('returns TransactionsRepository (cloud) when user is PRO', () {
      final container = _makeContainer(isPro: true, user: _fakeUser);
      addTearDown(container.dispose);

      final repo = container.read(transactionsRepositoryProvider);
      expect(repo, isA<TransactionsRepository>());
    });

    test('returns LocalTransactionsRepository when user is free and authenticated',
        () {
      final container = _makeContainer(isPro: false, user: _fakeUser);
      addTearDown(container.dispose);

      final repo = container.read(transactionsRepositoryProvider);
      expect(repo, isA<LocalTransactionsRepository>());
    });

    test('local repo has the correct userId', () {
      final container = _makeContainer(isPro: false, user: _fakeUser);
      addTearDown(container.dispose);

      final repo = container.read(transactionsRepositoryProvider)
          as LocalTransactionsRepository;
      expect(repo.userId, _fakeUser.id);
    });

    test('returns cloud repo when user is null (unauthenticated)', () {
      final container = _makeContainer(isPro: false, user: null);
      addTearDown(container.dispose);

      final repo = container.read(transactionsRepositoryProvider);
      expect(repo, isA<TransactionsRepository>());
    });

    test('returns cloud repo during sync (isSyncing=true) even if not PRO',
        () {
      final container =
          _makeContainer(isPro: false, user: _fakeUser, isSyncing: true);
      addTearDown(container.dispose);

      final repo = container.read(transactionsRepositoryProvider);
      expect(repo, isA<TransactionsRepository>());
    });

    test('switches to local after sync completes', () {
      // isSyncing = true → cloud
      final containerSyncing =
          _makeContainer(isPro: false, user: _fakeUser, isSyncing: true);
      addTearDown(containerSyncing.dispose);
      expect(containerSyncing.read(transactionsRepositoryProvider),
          isA<TransactionsRepository>());

      // isSyncing = false → local
      final containerDone =
          _makeContainer(isPro: false, user: _fakeUser, isSyncing: false);
      addTearDown(containerDone.dispose);
      expect(containerDone.read(transactionsRepositoryProvider),
          isA<LocalTransactionsRepository>());
    });
  });

  // ── recurringTransactionsRepositoryProvider ────────────────────────────────

  group('recurringTransactionsRepositoryProvider', () {
    test('returns RecurringTransactionsRepository (cloud) when user is PRO',
        () {
      final container = _makeContainer(isPro: true, user: _fakeUser);
      addTearDown(container.dispose);

      final repo = container.read(recurringTransactionsRepositoryProvider);
      expect(repo, isA<RecurringTransactionsRepository>());
    });

    test(
        'returns LocalRecurringTransactionsRepository when user is free and authenticated',
        () {
      final container = _makeContainer(isPro: false, user: _fakeUser);
      addTearDown(container.dispose);

      final repo = container.read(recurringTransactionsRepositoryProvider);
      expect(repo, isA<LocalRecurringTransactionsRepository>());
    });

    test('local recurring repo has the correct userId', () {
      final container = _makeContainer(isPro: false, user: _fakeUser);
      addTearDown(container.dispose);

      final repo = container.read(recurringTransactionsRepositoryProvider)
          as LocalRecurringTransactionsRepository;
      expect(repo.userId, _fakeUser.id);
    });

    test('returns cloud repo when unauthenticated', () {
      final container = _makeContainer(isPro: false, user: null);
      addTearDown(container.dispose);

      final repo = container.read(recurringTransactionsRepositoryProvider);
      expect(repo, isA<RecurringTransactionsRepository>());
    });

    test('returns cloud repo during sync even if not PRO', () {
      final container =
          _makeContainer(isPro: false, user: _fakeUser, isSyncing: true);
      addTearDown(container.dispose);

      final repo = container.read(recurringTransactionsRepositoryProvider);
      expect(repo, isA<RecurringTransactionsRepository>());
    });
  });
}
