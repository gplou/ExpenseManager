/// End-to-end test for the real [SyncNotifier] FREE→PRO migration path,
/// exercising `_runMigration` with in-memory local SQLite + fake cloud repos
/// (overriding the migration cloud-repo providers, so no Supabase is stubbed).
///
/// Reproduces the original bug scenario: an account that was PRO before still
/// has rows in the cloud; while FREE the user deletes some of them (recording
/// tombstones); on re-subscribing the deleted rows must NOT reappear.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/budgets/data/local_budgets_repository.dart';
import 'package:expense_manager/features/budgets/domain/budget_model.dart';
import 'package:expense_manager/features/budgets/domain/budgets_repository_contract.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_tombstoning_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_tombstoning_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/sync_queue_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/presentation/providers/sync_provider.dart';

import '../helpers/mocks.dart';

// ── In-memory cloud fakes ─────────────────────────────────────────────────────

class _FakeCloudTxRepo implements TransactionsRepositoryContract {
  final List<TransactionModel> data = [];

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) async =>
      List.of(data);

  @override
  Future<TransactionsSummary> getSummary(
          {required DateTime from, required DateTime to}) async =>
      const TransactionsSummary(income: 0, expense: 0);

  @override
  Future<TransactionModel> createTransaction(TransactionModel t) async => t;

  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) async => t;

  @override
  Future<void> deleteTransaction(String id) async =>
      data.removeWhere((t) => t.id == id);

  @override
  Future<void> upsertTransaction(TransactionModel t) async {
    data.removeWhere((e) => e.id == t.id);
    data.add(t);
  }
}

class _FakeCloudRecurringRepo implements RecurringTransactionsRepositoryContract {
  final List<RecurringTransactionModel> data = [];

  @override
  Future<List<RecurringTransactionModel>> getDueRecurring() async => List.of(data);

  @override
  Future<List<RecurringTransactionModel>> getAllForUser() async => List.of(data);

  @override
  Future<String> createRecurring({
    required double amount,
    required TransactionType type,
    required String category,
    String? subcategory,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  }) async =>
      'unused';

  @override
  Future<RecurringTransactionModel?> getById(String id) async =>
      data.where((r) => r.id == id).firstOrNull;

  @override
  Future<void> updateRecurring({
    required String id,
    required double amount,
    required TransactionType type,
    required String category,
    String? subcategory,
    String? description,
    required RecurrenceType recurrenceType,
    required DateTime nextOccurrence,
  }) async {}

  @override
  Future<void> updateNextOccurrence(String id, DateTime next) async {}

  @override
  Future<void> deleteRecurring(String id) async =>
      data.removeWhere((r) => r.id == id);

  @override
  Future<void> upsertRecurring(RecurringTransactionModel model) async {
    data.removeWhere((r) => r.id == model.id);
    data.add(model);
  }
}

class _FakeCloudBudgetsRepo implements CloudBudgetsRepo {
  final List<BudgetModel> data = [];

  @override
  Future<BudgetModel> upsertBudget(BudgetModel budget) async {
    data.removeWhere(
      (b) => b.userId == budget.userId && b.category == budget.category,
    );
    data.add(budget);
    return budget;
  }

  @override
  Future<List<BudgetModel>> getAllForUser() async => List.of(data);

  @override
  Future<void> deleteBudget(String id) async =>
      data.removeWhere((b) => b.id == id);
}

class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState();
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _userId = 'user-1';
final _user = UserModel(
  id: _userId,
  email: 'u@test.com',
  createdAt: DateTime(2024, 1, 1),
);

final _isProLever = StateProvider<bool>((ref) => false);

TransactionModel _tx(String id, {double amount = 50}) => TransactionModel(
      id: id,
      userId: _userId,
      amount: amount,
      type: TransactionType.expense,
      category: 'Comida',
      date: DateTime(2024, 3, 15),
      createdAt: DateTime(2024, 3, 15),
    );

RecurringTransactionModel _rec(String id) => RecurringTransactionModel(
      id: id,
      userId: _userId,
      amount: 30,
      type: TransactionType.expense,
      category: 'Suscripción',
      recurrenceType: RecurrenceType.monthly,
      nextOccurrence: DateTime(2024, 5, 1),
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late _FakeCloudTxRepo cloudTx;
  late _FakeCloudRecurringRepo cloudRecurring;
  late _FakeCloudBudgetsRepo cloudBudgets;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);
    cloudTx = _FakeCloudTxRepo();
    cloudRecurring = _FakeCloudRecurringRepo();
    cloudBudgets = _FakeCloudBudgetsRepo();
  });

  tearDown(() async {
    await LocalDatabase.instance.close();
  });

  ProviderContainer makeContainer() {
    final mockSupabase = MockSupabaseClient();
    final mockAuth = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(null);

    return ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => _user),
        isProProvider.overrideWith((ref) => ref.watch(_isProLever)),
        subscriptionProvider.overrideWith(_FakeSubscriptionNotifier.new),
        supabaseClientProvider.overrideWith((ref) => mockSupabase),
        cloudTxRepoForMigrationProvider.overrideWithValue(cloudTx),
        cloudRecurringRepoForMigrationProvider.overrideWithValue(cloudRecurring),
        cloudBudgetsRepoForMigrationProvider.overrideWithValue(cloudBudgets),
      ],
    );
  }

  Future<void> waitForMigration(ProviderContainer container) async {
    for (var i = 0; i < 200; i++) {
      if (container.read(syncProvider).value?.status == SyncStatus.done) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('FREE→PRO migration did not complete');
  }

  test(
      'FREE→PRO migration uploads kept rows and removes deleted ones from the '
      'cloud (transactions + recurring), so deletions do not reappear', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    // Cloud still holds the prior-PRO state.
    cloudTx.data.addAll([_tx('A'), _tx('B')]);
    cloudRecurring.data.addAll([_rec('R1'), _rec('R2')]);

    // Establish FREE state first so _previousIsPro = false.
    await container.read(subscriptionProvider.future);
    await container.read(syncProvider.future);
    container.listen(syncProvider, (_, __) {}); // keep the notifier alive

    // While FREE: local has A + B and R1 + R2; user deletes B and R2 (via the
    // tombstoning FREE repos), recording delete tombstones.
    final localTx = LocalTransactionsRepository(userId: _userId);
    final localRecurring = LocalRecurringTransactionsRepository(userId: _userId);
    final queue = SyncQueueRepository(userId: _userId);
    await localTx.insertAll([_tx('A'), _tx('B')]);
    await localRecurring.insertAll([_rec('R1'), _rec('R2')]);

    await LocalTombstoningTransactionsRepository(local: localTx, queue: queue)
        .deleteTransaction('B');
    await LocalTombstoningRecurringTransactionsRepository(
            local: localRecurring, queue: queue)
        .deleteRecurring('R2');

    // Sanity: tombstones recorded, local reflects the deletions.
    expect(await queue.pendingDeleteEntityIds(), contains('B'));
    expect(await queue.pendingRecurringDeleteEntityIds(), contains('R2'));

    // Re-subscribe: FREE → PRO triggers the real migration.
    container.read(_isProLever.notifier).state = true;
    await waitForMigration(container);

    // Cloud now mirrors the FREE state: kept rows present, deleted rows gone.
    expect(cloudTx.data.map((t) => t.id), contains('A'));
    expect(cloudTx.data.map((t) => t.id), isNot(contains('B')),
        reason: 'transaction deleted while FREE must not reappear in the cloud');
    expect(cloudRecurring.data.map((r) => r.id), contains('R1'));
    expect(cloudRecurring.data.map((r) => r.id), isNot(contains('R2')),
        reason: 'recurring deleted while FREE must not reappear in the cloud');

    // The queue is cleared after a successful migration.
    expect(await queue.getPending(), isEmpty);
  });

  test('FREE→PRO migration with no deletions leaves all cloud rows intact',
      () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    cloudTx.data.add(_tx('A'));
    cloudRecurring.data.add(_rec('R1'));

    await container.read(subscriptionProvider.future);
    await container.read(syncProvider.future);
    container.listen(syncProvider, (_, __) {});

    // Local mirrors the cloud, no tombstones.
    await LocalTransactionsRepository(userId: _userId).insertAll([_tx('A')]);
    await LocalRecurringTransactionsRepository(userId: _userId)
        .insertAll([_rec('R1')]);

    container.read(_isProLever.notifier).state = true;
    await waitForMigration(container);

    expect(cloudTx.data.map((t) => t.id), contains('A'));
    expect(cloudRecurring.data.map((r) => r.id), contains('R1'));
  });

  test(
      'FREE→PRO migration uploads budgets created while FREE to the cloud and '
      'clears them locally', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(subscriptionProvider.future);
    await container.read(syncProvider.future);
    container.listen(syncProvider, (_, __) {});

    // Budget created while FREE — local-only.
    final localBudgets = LocalBudgetsRepository(userId: _userId);
    final created = await localBudgets.createBudget(BudgetModel(
      id: '',
      userId: '',
      category: 'Comida',
      amount: 200,
      createdAt: DateTime(2026, 6, 1),
    ));

    container.read(_isProLever.notifier).state = true;
    await waitForMigration(container);

    // Budget is now in the cloud (preserving its id) and the local copy is
    // cleared (the PRO mirror re-hydrates from the cloud on next read).
    expect(cloudBudgets.data.single.category, 'Comida');
    expect(cloudBudgets.data.single.id, created.id);
    expect(await localBudgets.getBudgets(), isEmpty);
  });

  test(
      'FREE→PRO migration clears the hydration flag so the (just-emptied) local '
      'mirror is re-populated and budget spend is not stuck at 0', () async {
    // Simulate a user who was PRO on this device before: the flag is set, so
    // without clearing it InitialSyncService would skip re-hydration and the
    // local mirror (emptied by migrateToCloud) would stay empty.
    SharedPreferences.setMockInitialValues({'pro_hydrated_$_userId': true});

    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(subscriptionProvider.future);
    await container.read(syncProvider.future);
    container.listen(syncProvider, (_, __) {});

    await LocalTransactionsRepository(userId: _userId).insertAll([_tx('A')]);

    container.read(_isProLever.notifier).state = true;
    await waitForMigration(container);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pro_hydrated_$_userId'), isNot(true),
        reason: 'migration must clear the flag so the mirror re-hydrates');
  });
}
