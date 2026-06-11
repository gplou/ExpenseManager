/// Integration tests for [AllTransactionsNotifier].
///
/// Strategy:
///   - Real SQLite in-memory DB to verify what ends up in cache.
///   - Fake cloud repo returning canned data for full control.
///   - SharedPreferences mock to control the hydration flag.
///
/// Covers the two bug fixes:
///   1. _refreshInBackground must fetch from Supabase (not SQLite) so switching
///      from month to year returns the full annual data.
///   2. _saveToCache must be skipped when InitialSyncService hasn't hydrated yet,
///      preventing the race condition that caused duplicate-looking transactions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/initial_sync_service.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/pending_operation.dart';
import 'package:expense_manager/features/transactions/data/sync_queue_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _userId = 'user-pro';
const _hydrationKey = 'pro_hydrated_$_userId';

final _fakeUser = UserModel(
  id: _userId,
  email: 'pro@test.com',
  createdAt: DateTime(2024, 1, 1),
);

// ── Fake cloud repo ───────────────────────────────────────────────────────────

/// Returns only the transactions whose date falls within [from, to].
/// Comparison is day-precision only (matching Supabase/SQLite date string behavior).
class _FakeCloudTxRepo implements TransactionsRepositoryContract {
  _FakeCloudTxRepo({required this.data});

  final List<TransactionModel> data;

  static bool _inRange(DateTime date, DateTime from, DateTime to) {
    final d = DateTime(date.year, date.month, date.day);
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    return !d.isBefore(f) && !d.isAfter(t);
  }

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) async =>
      data.where((t) => _inRange(t.date, from, to)).toList();

  @override
  Future<TransactionsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final txs = await getTransactions(from: from, to: to);
    double income = 0, expense = 0;
    for (final t in txs) {
      if (t.type.isIncome) { income += t.amount; } else { expense += t.amount; }
    }
    return TransactionsSummary(income: income, expense: expense);
  }

  @override
  Future<TransactionModel> createTransaction(TransactionModel t) async => t;
  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) async => t;
  @override
  Future<void> deleteTransaction(String id) async {}
  @override
  Future<void> upsertTransaction(TransactionModel t) async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

TransactionModel _tx(String id, DateTime date, TransactionType type) =>
    TransactionModel(
      id: id,
      userId: _userId,
      amount: 100,
      type: type,
      category: 'Test',
      date: date,
      createdAt: DateTime.now(),
    );

/// Waits long enough for [Future] callbacks and async SQLite ops to finish.
Future<void> _pump() => Future.delayed(const Duration(milliseconds: 200));

ProviderContainer _makeContainer({
  required TransactionsRepositoryContract cloudRepo,
}) {
  return ProviderContainer(
    overrides: [
      isProProvider.overrideWith((ref) => true),
      currentUserProvider.overrideWith((ref) => _fakeUser),
      cloudTxRepoForHydrationProvider.overrideWith((ref) => cloudRepo),
      // Use local SQLite repo for the transactionsRepositoryProvider (PRO free
      // path won't be exercised, but it must be a valid value).
      transactionsRepositoryProvider.overrideWith(
        (ref) => LocalTransactionsRepository(userId: _userId),
      ),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);
  });

  tearDown(() async {
    await LocalDatabase.instance.close();
  });

  // ── Bug 1: _refreshInBackground fetches from cloud, not SQLite ────────────

  group('_refreshInBackground — fetches from cloud repo (Bug 1)', () {
    test(
        'updates state with full-year data even when SQLite only has current-month data',
        () async {
      final now = DateTime.now();
      // A date within the year range but outside the current month.
      // In January the year and month ranges coincide, so we fall back to the
      // 1st of the current month (same effect: the cloud data covers the full
      // year and both transactions end up in the final state).
      final olderDate = now.month > 1
          ? DateTime(now.year, 1, 1)
          : DateTime(now.year, now.month, 1);
      final januaryTx = _tx(
        'jan-tx',
        olderDate, // outside the current-month cache when month > 1
        TransactionType.expense,
      );
      // Use the 1st of the current month so it's always within [monthStart, today].
      final currentMonthTx = _tx(
        'month-tx',
        DateTime(now.year, now.month, 1),
        TransactionType.income,
      );

      // Seed SQLite with only the current-month transaction.
      final localRepo = LocalTransactionsRepository(userId: _userId);
      await localRepo.insertAll([currentMonthTx]);

      // Cloud has both transactions (full year).
      final cloudRepo = _FakeCloudTxRepo(data: [januaryTx, currentMonthTx]);

      final container = _makeContainer(cloudRepo: cloudRepo);
      addTearDown(container.dispose);

      // Start listening so the provider stays alive during the background refresh.
      final received = <List<TransactionModel>>[];
      final sub = container.listen<AsyncValue<List<TransactionModel>>>(
        allTransactionsProvider,
        (_, next) { if (next.hasValue) received.add(next.value!); },
      );
      addTearDown(sub.close);

      // Switch to year period — SQLite has the month tx (non-empty),
      // so the notifier returns it immediately and fires _refreshInBackground.
      container.read(selectedPeriodProvider.notifier).state = TransactionPeriod.year;

      // Wait for the initial SQLite read.
      await container.read(allTransactionsProvider.future);

      // Wait for the background Supabase refresh to complete.
      await _pump();

      final finalState = container.read(allTransactionsProvider).value;
      expect(
        finalState?.map((t) => t.id),
        containsAll(['jan-tx', 'month-tx']),
        reason:
            '_refreshInBackground must fetch the full-year range from Supabase, '
            'not just re-read the partial SQLite cache.',
      );
    });

    test('syncs SQLite cache after background refresh', () async {
      final now = DateTime.now();
      // Use the 1st of the current month — always ≤ today regardless of which
      // day of the month it is (avoids future-date exclusions on day 1).
      final monthStart = DateTime(now.year, now.month, 1);
      final cloudOnlyTx = _tx(
        'cloud-only',
        monthStart,
        TransactionType.expense,
      );
      final cachedTx = _tx(
        'cached',
        monthStart,
        TransactionType.income,
      );

      // SQLite has the cached tx; cloud has both (simulates a tx added on another device).
      final localRepo = LocalTransactionsRepository(userId: _userId);
      await localRepo.insertAll([cachedTx]);

      final cloudRepo = _FakeCloudTxRepo(data: [cloudOnlyTx, cachedTx]);

      final container = _makeContainer(cloudRepo: cloudRepo);
      addTearDown(container.dispose);

      final sub = container.listen(allTransactionsProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(allTransactionsProvider.future);
      await _pump();

      // SQLite must now reflect what cloud returned.
      final range = TransactionPeriod.month.dateRange;
      final cached = await localRepo.getTransactions(
        from: range.from,
        to: range.to,
      );

      expect(
        cached.map((t) => t.id),
        containsAll(['cloud-only', 'cached']),
        reason:
            'Background refresh must write the fresh cloud data back to SQLite.',
      );
    });

    test('does not update state when period changes mid-refresh (generation guard)',
        () async {
      final now = DateTime.now();
      // Always use the 1st of the month to avoid future-date exclusions.
      final monthTx = _tx('month', DateTime(now.year, now.month, 1), TransactionType.expense);
      // A date within the year range but outside the current month.
      // In January both ranges overlap, so we use the same month-start date.
      final olderDate = now.month > 1
          ? DateTime(now.year, 1, 1)
          : DateTime(now.year, now.month, 1);
      final yearTx = _tx('year', olderDate, TransactionType.income);

      final localRepo = LocalTransactionsRepository(userId: _userId);
      await localRepo.insertAll([monthTx]);

      final cloudRepo = _FakeCloudTxRepo(data: [monthTx, yearTx]);
      final container = _makeContainer(cloudRepo: cloudRepo);
      addTearDown(container.dispose);

      final sub = container.listen(allTransactionsProvider, (_, __) {});
      addTearDown(sub.close);

      // Start on year period → background refresh fires.
      container.read(selectedPeriodProvider.notifier).state = TransactionPeriod.year;
      await container.read(allTransactionsProvider.future);

      // Immediately switch back to month before the refresh completes.
      // This increments the generation, so the stale refresh must be discarded.
      container.read(selectedPeriodProvider.notifier).state = TransactionPeriod.month;
      await container.read(allTransactionsProvider.future);

      await _pump();

      // Final state must be month data, not year data written by the stale refresh.
      final finalIds = container.read(allTransactionsProvider).value?.map((t) => t.id);
      expect(
        finalIds,
        isNot(contains('year')),
        reason:
            'Stale background refresh (cancelled by generation guard) must not '
            'overwrite the state set by the newer period.',
      );
    });

    test(
        'preserves a locally-created pending tx not present in the cloud (localToKeep)',
        () async {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      // A tx that lives only locally (offline create, sitting in the queue) and
      // is NOT returned by the cloud. The merge must keep it after the refresh.
      final pendingTx = _tx('pending-local', monthStart, TransactionType.expense);
      // A tx that exists both locally and in the cloud (normal synced tx).
      final syncedTx = _tx('synced', monthStart, TransactionType.income);

      final localRepo = LocalTransactionsRepository(userId: _userId);
      await localRepo.insertAll([pendingTx, syncedTx]);

      // Mark pendingTx as a pending create so localToKeep keeps it.
      final queue = SyncQueueRepository(userId: _userId);
      await queue.enqueue(PendingOperation(
        id: 'pending-local_create',
        userId: _userId,
        opType: SyncOpType.create,
        entityId: 'pending-local',
        createdAt: now,
      ));

      // Cloud only knows about the synced tx.
      final cloudRepo = _FakeCloudTxRepo(data: [syncedTx]);
      final container = _makeContainer(cloudRepo: cloudRepo);
      addTearDown(container.dispose);

      final sub = container.listen(allTransactionsProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(allTransactionsProvider.future);
      await _pump();

      final finalIds =
          container.read(allTransactionsProvider).value?.map((t) => t.id);
      expect(
        finalIds,
        containsAll(['pending-local', 'synced']),
        reason:
            'A locally-created pending tx absent from the cloud must survive the '
            'background refresh merge (localToKeep), not be wiped by '
            'deleteByDateRange.',
      );

      // And it must remain in the SQLite cache after the write-back.
      final cached = await localRepo.getTransactions(
        from: monthStart,
        to: now,
      );
      expect(
        cached.map((t) => t.id),
        contains('pending-local'),
        reason: 'localToKeep entries must be re-inserted into the cache.',
      );
    });
  });

  // ── Bug 2: _saveToCache skipped until InitialSyncService hydrates ─────────

  group('_saveToCache — respects hydration flag (Bug 2)', () {
    test(
        'does NOT write to SQLite when hydration flag is not set (first launch)',
        () async {
      // Hydration flag NOT set — InitialSyncService has not run yet.
      final now = DateTime.now();
      final cloudTx = _tx(
        'cloud-1',
        DateTime(now.year, now.month, 1), // first of month — always in range
        TransactionType.income,
      );
      final cloudRepo = _FakeCloudTxRepo(data: [cloudTx]);

      final container = _makeContainer(cloudRepo: cloudRepo);
      addTearDown(container.dispose);

      // Keep the autoDispose provider alive across the build's async gaps.
      final sub = container.listen(allTransactionsProvider, (_, __) {});
      addTearDown(sub.close);

      // SQLite is empty → falls into the no-cache path → fetches from Supabase.
      final txs = await container.read(allTransactionsProvider.future);
      await _pump();

      // State must show the cloud data.
      expect(txs.map((t) => t.id), contains('cloud-1'),
          reason: 'State must be populated from Supabase even without cache.');

      // SQLite must still be EMPTY — _saveToCache must have been skipped.
      final localRepo = LocalTransactionsRepository(userId: _userId);
      final inDb = await localRepo.getTransactions(
        from: DateTime(2000),
        to: DateTime(2099),
      );
      expect(
        inDb,
        isEmpty,
        reason:
            'When the hydration flag is not set, _saveToCache must be skipped '
            'to avoid racing with InitialSyncService.',
      );
    });

    test(
        'DOES write to SQLite when hydration flag is already set',
        () async {
      // Hydration flag SET — InitialSyncService already ran on a previous session.
      SharedPreferences.setMockInitialValues({_hydrationKey: true});

      final now = DateTime.now();
      final cloudTx = _tx(
        'cloud-2',
        DateTime(now.year, now.month, 1), // first of month — always in range
        TransactionType.expense,
      );
      final cloudRepo = _FakeCloudTxRepo(data: [cloudTx]);

      final container = _makeContainer(cloudRepo: cloudRepo);
      addTearDown(container.dispose);

      // Keep the autoDispose provider alive across the build's async gaps.
      final sub = container.listen(allTransactionsProvider, (_, __) {});
      addTearDown(sub.close);

      // SQLite is empty → no-cache path → must fetch AND cache.
      await container.read(allTransactionsProvider.future);
      await _pump();

      final localRepo = LocalTransactionsRepository(userId: _userId);
      final inDb = await localRepo.getTransactions(
        from: DateTime(2000),
        to: DateTime(2099),
      );
      expect(
        inDb.map((t) => t.id),
        contains('cloud-2'),
        reason:
            'When the hydration flag is set, _saveToCache must persist the '
            'Supabase data to SQLite for fast future startups.',
      );
    });
  });

  // ── F12: _saveToCache es best-effort ───────────────────────────────────────

  group('_saveToCache — best-effort (F12)', () {
    test('a failing local cache write neither crashes nor hides cloud data',
        () async {
      // Hidratación ya completada → el notifier intentará _saveToCache.
      SharedPreferences.setMockInitialValues({_hydrationKey: true});

      final now = DateTime.now();
      final cloudTx =
          _tx('cloud-1', DateTime(now.year, now.month, 1), TransactionType.expense);
      final container =
          _makeContainer(cloudRepo: _FakeCloudTxRepo(data: [cloudTx]));
      addTearDown(container.dispose);

      // Simula SQLite no disponible (Keystore hang / DB corrupta): sin BD de
      // test, cualquier acceso intenta abrir la real y falla en el entorno
      // de test (MissingPluginException de path_provider).
      await LocalDatabase.instance.close();

      final result = await container.read(allTransactionsProvider.future);
      expect(
        result.map((t) => t.id),
        contains('cloud-1'),
        reason: 'El fallo del caché local no debe ocultar los datos del cloud.',
      );

      // El write en background falla en silencio: si lanzara un unhandled
      // async error, el propio runner del test fallaría aquí.
      await _pump();
    });
  });
}
