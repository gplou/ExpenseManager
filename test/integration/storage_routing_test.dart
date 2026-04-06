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

/// Fake SyncNotifier that exposes a fixed [SyncState] without running any
/// migration logic, so routing tests are not affected by async side effects.
///
/// Explicitly assigns [state] inside [build] so the value is visible
/// synchronously to providers that watch [syncProvider] during the same
/// evaluation pass (Dart async functions run synchronously up to the first
/// await, so the assignment happens before any watcher reads the state).
class _FakeSyncNotifier extends SyncNotifier {
  _FakeSyncNotifier(this._state);
  final SyncState _state;

  @override
  Future<SyncState> build() async {
    // Setting state here runs synchronously before the first suspension point,
    // making the value available to dependent providers in the same read pass.
    state = AsyncData(_state);
    return _state;
  }
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

  // ── Repository stability (no spurious rebuilds) ────────────────────────────
  //
  // Verifies that [transactionsRepositoryProvider] and
  // [recurringTransactionsRepositoryProvider] return the *same instance* when
  // syncProvider emits a new state but [isSyncing] does not change.
  // Before the .select() fix, every AsyncNotifier state transition (e.g.
  // AsyncLoading → AsyncData) caused the provider to rebuild and create a new
  // LocalRepository instance, triggering an unnecessary double-fetch.

  group('repository stability — no rebuild when isSyncing is unchanged', () {
    /// A [_FakeSyncNotifier] subclass whose state can be updated after build,
    /// simulating the AsyncLoading → AsyncData(idle) transition.
    ProviderContainer makeContainerWithLiveSyncNotifier({
      required bool isPro,
      required UserModel user,
    }) {
      final mockSupabase = MockSupabaseClient();
      when(() => mockSupabase.auth).thenReturn(MockGoTrueClient());

      return ProviderContainer(
        overrides: [
          isProProvider.overrideWith((ref) => isPro),
          currentUserProvider.overrideWith((ref) => user),
          // Start with isSyncing = false (idle).
          syncProvider.overrideWith(() => _FakeSyncNotifier(const SyncState())),
          supabaseClientProvider.overrideWith((ref) => mockSupabase),
        ],
      );
    }

    test(
        'transactionsRepositoryProvider returns same instance '
        'when syncProvider state changes but isSyncing stays false', () {
      final container = makeContainerWithLiveSyncNotifier(
        isPro: false,
        user: _fakeUser,
      );
      addTearDown(container.dispose);

      final repo1 = container.read(transactionsRepositoryProvider);

      // Simulate syncProvider emitting a new-but-equivalent state (e.g. done).
      // isSyncing is still false — the provider must not rebuild.
      container
          .read(syncProvider.notifier)
          .state = const AsyncData(SyncState(status: SyncStatus.done));

      final repo2 = container.read(transactionsRepositoryProvider);

      expect(identical(repo1, repo2), isTrue,
          reason: 'A new repository instance would cause allTransactionsProvider '
              'to re-fetch unnecessarily');
    });

    test(
        'recurringTransactionsRepositoryProvider returns same instance '
        'when syncProvider state changes but isSyncing stays false', () {
      final container = makeContainerWithLiveSyncNotifier(
        isPro: false,
        user: _fakeUser,
      );
      addTearDown(container.dispose);

      final repo1 = container.read(recurringTransactionsRepositoryProvider);

      container
          .read(syncProvider.notifier)
          .state = const AsyncData(SyncState(status: SyncStatus.done));

      final repo2 = container.read(recurringTransactionsRepositoryProvider);

      expect(identical(repo1, repo2), isTrue);
    });

    test(
        'transactionsRepositoryProvider DOES return new instance '
        'when isSyncing changes true → false (sync completes)', () {
      final container = makeContainerWithLiveSyncNotifier(
        isPro: false,
        user: _fakeUser,
      );
      addTearDown(container.dispose);

      // During sync: cloud repo.
      container
          .read(syncProvider.notifier)
          .state = const AsyncData(SyncState(status: SyncStatus.syncing));
      final repoSyncing = container.read(transactionsRepositoryProvider);
      expect(repoSyncing, isA<TransactionsRepository>());

      // Sync done: local repo.
      container
          .read(syncProvider.notifier)
          .state = const AsyncData(SyncState(status: SyncStatus.done));
      final repoDone = container.read(transactionsRepositoryProvider);
      expect(repoDone, isA<LocalTransactionsRepository>());
    });
  });
}
