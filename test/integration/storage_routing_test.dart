/// Tests that [transactionsRepositoryProvider] and
/// [recurringTransactionsRepositoryProvider] return the correct concrete
/// implementation depending on the user's PRO status and sync state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/core/network/connectivity_service.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/offline_aware_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/presentation/providers/sync_provider.dart';

import '../helpers/mocks.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

final _fakeUser = UserModel(
  id: 'user-abc',
  email: 'test@example.com',
  createdAt: DateTime(2024, 1, 1),
);

/// Fake SyncNotifier that exposes a fixed [SyncState] without running any
/// migration logic, so routing tests are not affected by async side effects.
class _FakeSyncNotifier extends SyncNotifier {
  _FakeSyncNotifier(this._state);
  final SyncState _state;

  @override
  Future<SyncState> build() async {
    state = AsyncData(_state);
    return _state;
  }
}

ProviderContainer _makeContainer({
  required bool isPro,
  UserModel? user,
  bool isSyncing = false,
  bool isOnline = true,
}) {
  final mockSupabase = MockSupabaseClient();
  when(() => mockSupabase.auth).thenReturn(MockGoTrueClient());

  return ProviderContainer(
    overrides: [
      isProProvider.overrideWith((ref) => isPro),
      currentUserProvider.overrideWith((ref) => user),
      syncProvider.overrideWith(
        () => _FakeSyncNotifier(
          SyncState(status: isSyncing ? SyncStatus.syncing : SyncStatus.idle),
        ),
      ),
      supabaseClientProvider.overrideWith((ref) => mockSupabase),
      // Override connectivity to avoid EventChannel in unit tests.
      isOnlineProvider.overrideWith((ref) => isOnline),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── transactionsRepositoryProvider ────────────────────────────────────────

  group('transactionsRepositoryProvider', () {
    test('returns OfflineAwareTransactionsRepository when user is PRO', () {
      final container = _makeContainer(isPro: true, user: _fakeUser);
      addTearDown(container.dispose);

      final repo = container.read(transactionsRepositoryProvider);
      expect(repo, isA<OfflineAwareTransactionsRepository>());
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

    test('returns cloud repo during sync (isSyncing=true) even if not PRO', () {
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

    test('PRO online returns OfflineAwareTransactionsRepository', () {
      final container =
          _makeContainer(isPro: true, user: _fakeUser, isOnline: true);
      addTearDown(container.dispose);

      expect(
        container.read(transactionsRepositoryProvider),
        isA<OfflineAwareTransactionsRepository>(),
      );
    });

    test('PRO offline also returns OfflineAwareTransactionsRepository', () {
      final container =
          _makeContainer(isPro: true, user: _fakeUser, isOnline: false);
      addTearDown(container.dispose);

      expect(
        container.read(transactionsRepositoryProvider),
        isA<OfflineAwareTransactionsRepository>(),
      );
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

  group('repository stability — no rebuild when isSyncing is unchanged', () {
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
          syncProvider.overrideWith(() => _FakeSyncNotifier(const SyncState())),
          supabaseClientProvider.overrideWith((ref) => mockSupabase),
          isOnlineProvider.overrideWith((ref) => true),
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

      container.read(syncProvider.notifier).state =
          const AsyncData(SyncState(status: SyncStatus.done));

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

      container.read(syncProvider.notifier).state =
          const AsyncData(SyncState(status: SyncStatus.done));

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
      container.read(syncProvider.notifier).state =
          const AsyncData(SyncState(status: SyncStatus.syncing));
      final repoSyncing = container.read(transactionsRepositoryProvider);
      expect(repoSyncing, isA<TransactionsRepository>());

      // Sync done: local repo.
      container.read(syncProvider.notifier).state =
          const AsyncData(SyncState(status: SyncStatus.done));
      final repoDone = container.read(transactionsRepositoryProvider);
      expect(repoDone, isA<LocalTransactionsRepository>());
    });
  });
}
