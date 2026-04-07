import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../subscription/subscription_provider.dart';
import '../domain/recurring_transactions_repository_contract.dart';
import '../domain/transactions_repository_contract.dart';
import '../presentation/providers/sync_provider.dart';
import '../presentation/providers/transactions_provider.dart';
import 'local_recurring_transactions_repository.dart';
import 'local_transactions_repository.dart';
import 'recurring_transactions_repository.dart';
import 'transaction_sync_service.dart';
import 'transactions_repository.dart';

/// Cloud-only repos used exclusively by [InitialSyncService] for hydration.
/// Exposed as providers so tests can override them with fakes/mocks.
final cloudTxRepoForHydrationProvider =
    Provider<TransactionsRepositoryContract>(
  (ref) => TransactionsRepository(ref.read(supabaseClientProvider)),
);

final cloudRecurringRepoForHydrationProvider =
    Provider<RecurringTransactionsRepositoryContract>(
  (ref) => RecurringTransactionsRepository(ref.read(supabaseClientProvider)),
);

/// Provider that starts [InitialSyncService] once and keeps it alive.
/// Watch it from the root widget alongside [offlineSyncServiceProvider].
final initialSyncServiceProvider = Provider<void>((ref) {
  InitialSyncService(ref).start();
});

/// Hydrates the local SQLite cache from Supabase on the first launch for
/// PRO users — covers fresh installs, reinstalls, and device changes.
///
/// Flow:
///   1. On app start, check SharedPreferences for `pro_hydrated_{userId}`.
///   2. If not set, wait until online + PRO + not mid-migration, then run
///      [TransactionSyncService.hydrateLocalFromCloud].
///   3. On success, set the flag and refresh the UI.
///   4. Retries automatically on connectivity restore or after migration ends.
///
/// The flag is per-user so account switching works correctly, and it is
/// cleared on reinstall (SharedPreferences is wiped) to re-trigger hydration.
class InitialSyncService {
  InitialSyncService(this._ref);

  final Ref _ref;
  bool _running = false;

  void start() {
    // Attempt immediately in case everything is already ready.
    Future.microtask(_tryHydrate);

    // Retry when the device comes back online (was offline → now online).
    _ref.listen(connectivityProvider, (prev, next) {
      final isOnline = next.valueOrNull ?? false;
      final wasOffline = !(prev?.valueOrNull ?? true);
      if (isOnline && wasOffline) _tryHydrate();
    });

    // Retry when the subscription finishes loading (async start-up).
    _ref.listen(
      subscriptionProvider.select((s) => s.hasValue),
      (prev, next) {
        if (next == true && prev != true) _tryHydrate();
      },
    );

    // Retry after a FREE→PRO migration completes (it clears local; we must
    // re-populate from cloud even though the flag may not be set yet).
    _ref.listen(
      syncProvider.select((s) => s.valueOrNull?.isSyncing ?? false),
      (prev, next) {
        if (prev == true && next == false) _tryHydrate();
      },
    );
  }

  Future<void> _tryHydrate() async {
    if (_running) return;

    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final isPro = _ref.read(isProProvider);
    if (!isPro) return;

    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) return;

    // Don't start while a FREE↔PRO migration is already running.
    final isSyncing = _ref.read(
      syncProvider.select((s) => s.valueOrNull?.isSyncing ?? false),
    );
    if (isSyncing) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _hydrationKey(user.id);
    if (prefs.getBool(key) == true) return;

    _running = true;
    try {
      final service = TransactionSyncService(
        localTx: LocalTransactionsRepository(userId: user.id),
        cloudTx: _ref.read(cloudTxRepoForHydrationProvider),
        localRecurring: LocalRecurringTransactionsRepository(userId: user.id),
        cloudRecurring: _ref.read(cloudRecurringRepoForHydrationProvider),
      );
      await service.hydrateLocalFromCloud();
      await prefs.setBool(key, true);
      _ref.invalidate(allTransactionsProvider);
    } catch (e) {
      // Leave the flag unset — will retry on next connectivity restore or start.
      debugPrint('InitialSyncService: hydration failed, will retry: $e');
    } finally {
      _running = false;
    }
  }

  /// SharedPreferences key used to track whether initial hydration has been
  /// performed for a given user on this device installation.
  static String _hydrationKey(String userId) => 'pro_hydrated_$userId';

  /// Clears the hydration flag for [userId]. Exposed for testing and for
  /// cases where a forced re-sync is needed (e.g. debug/support tooling).
  static Future<void> clearHydrationFlag(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hydrationKey(userId));
  }
}
