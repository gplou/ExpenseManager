/// Tests that [transactionsRepositoryProvider] and
/// [recurringTransactionsRepositoryProvider] return the correct concrete
/// implementation depending on the user's PRO status and sync state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/core/network/connectivity_service.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_tombstoning_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_tombstoning_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/offline_aware_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/presentation/providers/sync_provider.dart';

import '../helpers/mocks.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Returns an immediately-loaded empty SubscriptionState so that
/// [subscriptionProvider].hasValue is true and [transactionsRepositoryProvider]
/// does not treat the subscription as "still loading".
class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState();
}

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
      subscriptionProvider.overrideWith(_FakeSubscriptionNotifier.new),
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

    test('returns LocalTombstoningTransactionsRepository when user is free and authenticated',
        () async {
      final container = _makeContainer(isPro: false, user: _fakeUser);
      addTearDown(container.dispose);
      await container.read(subscriptionProvider.future);

      // FREE writes stay local but deletions are recorded as tombstones for the
      // next FREE→PRO migration — hence the decorator, not the raw local repo.
      final repo = container.read(transactionsRepositoryProvider);
      expect(repo, isA<LocalTombstoningTransactionsRepository>());
    });

    test('local repo has the correct userId', () async {
      final container = _makeContainer(isPro: false, user: _fakeUser);
      addTearDown(container.dispose);
      await container.read(subscriptionProvider.future);

      // The decorator wraps the user-scoped local repo; assert that wrapped repo.
      final local = container.read(localTransactionsRepositoryProvider);
      expect(local.userId, _fakeUser.id);
    });

    test('returns cloud repo when user is null (unauthenticated)', () {
      final container = _makeContainer(isPro: false, user: null);
      addTearDown(container.dispose);

      final repo = container.read(transactionsRepositoryProvider);
      expect(repo, isA<TransactionsRepository>());
    });

    test('returns cloud repo during a FREE→PRO sync (isSyncing + PRO)', () {
      // Durante la subida a la nube el local está a punto de vaciarse, así que
      // leer/escribir contra Supabase directo es lo correcto.
      final container =
          _makeContainer(isPro: true, user: _fakeUser, isSyncing: true);
      addTearDown(container.dispose);

      final repo = container.read(transactionsRepositoryProvider);
      expect(repo, isA<TransactionsRepository>());
    });

    test(
        'returns local tombstoning repo during a PRO→FREE sync '
        '(writes must land in the destination store, not the cloud)', () async {
      // Regresión: antes isSyncing forzaba Supabase directo en ambas
      // direcciones; una transacción creada durante el downgrade acababa solo
      // en la nube y quedaba invisible para el usuario FREE.
      final container =
          _makeContainer(isPro: false, user: _fakeUser, isSyncing: true);
      addTearDown(container.dispose);
      await container.read(subscriptionProvider.future);

      final repo = container.read(transactionsRepositoryProvider);
      expect(repo, isA<LocalTombstoningTransactionsRepository>());
    });

    test('switches from cloud to local when the user ends up FREE', () async {
      // FREE→PRO sync in progress (PRO) → cloud.
      final containerSyncing =
          _makeContainer(isPro: true, user: _fakeUser, isSyncing: true);
      addTearDown(containerSyncing.dispose);
      expect(containerSyncing.read(transactionsRepositoryProvider),
          isA<TransactionsRepository>());

      // isSyncing = false, FREE → local (subscriptionLoaded must be true)
      final containerDone =
          _makeContainer(isPro: false, user: _fakeUser, isSyncing: false);
      addTearDown(containerDone.dispose);
      await containerDone.read(subscriptionProvider.future);
      expect(containerDone.read(transactionsRepositoryProvider),
          isA<LocalTombstoningTransactionsRepository>());
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

    test('repo instance is STABLE across connectivity changes', () async {
      // Regresión: el provider watcheaba isOnlineProvider, así que cada cambio
      // de red reconstruía el repo y recargaba allTransactionsProvider.
      final onlineFlag = StateProvider<bool>((ref) => true);
      final mockSupabase = MockSupabaseClient();
      when(() => mockSupabase.auth).thenReturn(MockGoTrueClient());

      final container = ProviderContainer(
        overrides: [
          isProProvider.overrideWith((ref) => true),
          currentUserProvider.overrideWith((ref) => _fakeUser),
          subscriptionProvider.overrideWith(_FakeSubscriptionNotifier.new),
          syncProvider.overrideWith(
            () => _FakeSyncNotifier(const SyncState(status: SyncStatus.idle)),
          ),
          supabaseClientProvider.overrideWith((ref) => mockSupabase),
          isOnlineProvider.overrideWith((ref) => ref.watch(onlineFlag)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(subscriptionProvider.future);

      final repoBefore = container.read(transactionsRepositoryProvider);
      container.read(onlineFlag.notifier).state = false;
      await Future<void>.delayed(Duration.zero);
      final repoAfter = container.read(transactionsRepositoryProvider);

      expect(
        identical(repoBefore, repoAfter),
        isTrue,
        reason: 'Un cambio de conectividad no debe reconstruir el repo '
            '(provocaba recargas completas del listado).',
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
        'returns LocalTombstoningRecurringTransactionsRepository when user is free and authenticated',
        () {
      final container = _makeContainer(isPro: false, user: _fakeUser);
      addTearDown(container.dispose);

      // FREE writes stay local but recurring deletions are tombstoned for the
      // next FREE→PRO migration — hence the decorator, not the raw local repo.
      final repo = container.read(recurringTransactionsRepositoryProvider);
      expect(repo, isA<LocalTombstoningRecurringTransactionsRepository>());
    });

    test('local recurring repo has the correct userId', () {
      final container = _makeContainer(isPro: false, user: _fakeUser);
      addTearDown(container.dispose);

      // The decorator wraps the user-scoped local repo; assert that wrapped repo.
      final local =
          container.read(localRecurringTransactionsRepositoryProvider);
      expect(local.userId, _fakeUser.id);
    });

    test('returns cloud repo when unauthenticated', () {
      final container = _makeContainer(isPro: false, user: null);
      addTearDown(container.dispose);

      final repo = container.read(recurringTransactionsRepositoryProvider);
      expect(repo, isA<RecurringTransactionsRepository>());
    });

    test('returns local tombstoning repo during a PRO→FREE sync', () {
      // Igual que con las transacciones: durante el downgrade las escrituras
      // de recurrentes deben ir al store local (el destino), no a Supabase.
      final container =
          _makeContainer(isPro: false, user: _fakeUser, isSyncing: true);
      addTearDown(container.dispose);

      final repo = container.read(recurringTransactionsRepositoryProvider);
      expect(repo, isA<LocalTombstoningRecurringTransactionsRepository>());
    });

    test('returns cloud repo during a FREE→PRO sync (PRO)', () {
      final container =
          _makeContainer(isPro: true, user: _fakeUser, isSyncing: true);
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
          subscriptionProvider.overrideWith(_FakeSubscriptionNotifier.new),
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
        'when isSyncing changes true → false (sync completes)', () async {
      final container = makeContainerWithLiveSyncNotifier(
        isPro: true,
        user: _fakeUser,
      );
      addTearDown(container.dispose);

      await container.read(subscriptionProvider.future);

      // During a FREE→PRO sync: direct cloud repo.
      container.read(syncProvider.notifier).state =
          const AsyncData(SyncState(status: SyncStatus.syncing));
      final repoSyncing = container.read(transactionsRepositoryProvider);
      expect(repoSyncing, isA<TransactionsRepository>());

      // Sync done: PRO offline-aware repo.
      container.read(syncProvider.notifier).state =
          const AsyncData(SyncState(status: SyncStatus.done));
      final repoDone = container.read(transactionsRepositoryProvider);
      expect(repoDone, isA<OfflineAwareTransactionsRepository>());
    });
  });
}
