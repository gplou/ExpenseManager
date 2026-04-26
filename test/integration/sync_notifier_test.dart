/// Tests for [SyncNotifier] — migration triggers and account-switch protection.
///
/// Key invariants under test:
///   1. No migration on first login (no previous state to compare against).
///   2. Migration IS triggered when the *same* user changes subscription status.
///   3. Migration is NOT triggered when a different user logs in, even if the
///      isPro value changes — that is an account switch, not an upgrade/downgrade.
///   4. State resets correctly on logout so the next login starts fresh.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/features/transactions/presentation/providers/sync_provider.dart';

import '../helpers/mocks.dart';

// ── Fake subscription notifier ────────────────────────────────────────────────
// Returns an immediately-loaded empty state so SyncNotifier's
// `subscriptionLoaded` guard doesn't bail out early during tests.
class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState();
}

// ── Test fixtures ──────────────────────────────────────────────────────────────

final _userA = UserModel(
  id: 'user-a',
  email: 'a@test.com',
  createdAt: DateTime(2024, 1, 1),
);

final _userB = UserModel(
  id: 'user-b',
  email: 'b@test.com',
  createdAt: DateTime(2024, 1, 1),
);

// ── Mutable state levers ───────────────────────────────────────────────────────
//
// These StateProviders let each test drive [isProProvider] and
// [currentUserProvider] without touching the real auth/subscription stack.

final _isProLever = StateProvider<bool>((ref) => false);
final _userLever = StateProvider<UserModel?>((ref) => null);

// ── Container factory ─────────────────────────────────────────────────────────

ProviderContainer _makeContainer() {
  final mockSupabase = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();
  when(() => mockSupabase.auth).thenReturn(mockAuth);
  // currentUser is accessed by AuthenticatedRepository inside the migration;
  // returning null is fine — the migration will throw and be caught silently.
  when(() => mockAuth.currentUser).thenReturn(null);

  return ProviderContainer(
    overrides: [
      isProProvider.overrideWith((ref) => ref.watch(_isProLever)),
      currentUserProvider.overrideWith((ref) => ref.watch(_userLever)),
      subscriptionProvider.overrideWith(_FakeSubscriptionNotifier.new),
      supabaseClientProvider.overrideWith((ref) => mockSupabase),
    ],
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Sets both levers, then waits for [syncProvider] to finish rebuilding.
Future<SyncState> _setAndRead(
  ProviderContainer container, {
  required UserModel? user,
  required bool isPro,
}) async {
  container.read(_userLever.notifier).state = user;
  container.read(_isProLever.notifier).state = isPro;
  // Ensure subscriptionProvider has resolved before reading syncProvider.
  // SyncNotifier.build() guards on subscriptionLoaded (hasValue); if we read
  // syncProvider while subscription is still AsyncLoading the guard fires an
  // early return and the test sees the wrong state.
  await container.read(subscriptionProvider.future);
  return container.read(syncProvider.future);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();

  setUpAll(() async {
    // Provide an in-memory DB so background migrations don't crash trying to
    // open a real file; errors are caught inside _runMigration anyway.
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);
  });

  tearDownAll(() async {
    await LocalDatabase.instance.close();
  });

  // ── First login ────────────────────────────────────────────────────────────

  group('first login — no previous state', () {
    test('no migration when non-PRO user logs in for the first time', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final state = await _setAndRead(container, user: _userA, isPro: false);

      expect(state.isSyncing, isFalse);
    });

    test('no migration when PRO user logs in for the first time', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final state = await _setAndRead(container, user: _userA, isPro: true);

      expect(state.isSyncing, isFalse);
    });
  });

  // ── Same user changes subscription ────────────────────────────────────────

  group('same user — subscription change triggers migration', () {
    test('triggers migration when same user upgrades (free → PRO)', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // Establish initial state: user A, non-PRO.
      await _setAndRead(container, user: _userA, isPro: false);

      // Same user purchases PRO.
      final state = await _setAndRead(container, user: _userA, isPro: true);

      expect(state.isSyncing, isTrue);
    });

    test('triggers migration when same user downgrades (PRO → free)', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await _setAndRead(container, user: _userA, isPro: true);

      final state = await _setAndRead(container, user: _userA, isPro: false);

      expect(state.isSyncing, isTrue);
    });
  });

  // ── Account switch — different user ───────────────────────────────────────

  group('account switch — no migration regardless of isPro change', () {
    test('no migration: PRO account → non-PRO account', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // User A (PRO) is logged in.
      await _setAndRead(container, user: _userA, isPro: true);

      // User B (non-PRO) logs in on the same device.
      final state = await _setAndRead(container, user: _userB, isPro: false);

      expect(state.isSyncing, isFalse,
          reason: 'isPro changed because a different account logged in, '
              'not because this account was downgraded');
    });

    test('no migration: non-PRO account → PRO account', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await _setAndRead(container, user: _userA, isPro: false);

      final state = await _setAndRead(container, user: _userB, isPro: true);

      expect(state.isSyncing, isFalse,
          reason: 'isPro changed because a different PRO account logged in, '
              'not because this account was upgraded');
    });

    test('no migration: non-PRO account → non-PRO account', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await _setAndRead(container, user: _userA, isPro: false);

      final state = await _setAndRead(container, user: _userB, isPro: false);

      expect(state.isSyncing, isFalse);
    });

    test('after account switch, subscription change for new user triggers migration',
        () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // User A (PRO) → user B (non-PRO): account switch, no migration.
      await _setAndRead(container, user: _userA, isPro: true);
      await _setAndRead(container, user: _userB, isPro: false);

      // User B upgrades to PRO: should migrate B's local data to cloud.
      final state = await _setAndRead(container, user: _userB, isPro: true);

      expect(state.isSyncing, isTrue,
          reason: 'this is a genuine upgrade for user B, not an account switch');
    });
  });

  // ── Logout ─────────────────────────────────────────────────────────────────

  group('logout resets state', () {
    test('returns idle when user logs out', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await _setAndRead(container, user: _userA, isPro: true);

      final state = await _setAndRead(container, user: null, isPro: false);

      expect(state.isSyncing, isFalse);
    });

    test('no migration when a new user logs in after logout', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // User A (PRO) logs in and then out.
      await _setAndRead(container, user: _userA, isPro: true);
      await _setAndRead(container, user: null, isPro: false);

      // User B (non-PRO) logs in — _previousUserId was reset on logout.
      final state = await _setAndRead(container, user: _userB, isPro: false);

      expect(state.isSyncing, isFalse,
          reason: 'previous user state was cleared on logout; '
              'this is a fresh first-login for user B');
    });

    test('same user logging back in after logout does not trigger migration',
        () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await _setAndRead(container, user: _userA, isPro: false);
      await _setAndRead(container, user: null, isPro: false); // logout

      // Same user logs back in with the same subscription status.
      final state = await _setAndRead(container, user: _userA, isPro: false);

      expect(state.isSyncing, isFalse);
    });
  });
}
