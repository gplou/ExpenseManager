import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/core/services/sentry_service.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/sync_queue_repository.dart';
import 'package:expense_manager/features/transactions/data/transaction_sync_service.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';

enum SyncStatus { idle, syncing, done, error }

class SyncState {
  const SyncState({this.status = SyncStatus.idle, this.error});
  final SyncStatus status;
  final String? error;

  bool get isSyncing => status == SyncStatus.syncing;
}

class SyncNotifier extends AsyncNotifier<SyncState> {
  bool? _previousIsPro;
  String? _previousUserId;

  /// Set to true in ref.onDispose so any in-flight migration aborts cleanly
  /// instead of writing to a stale notifier after logout or account switch.
  bool _cancelled = false;

  @override
  Future<SyncState> build() async {
    _cancelled = false;
    ref.onDispose(() => _cancelled = true);

    final isPro = ref.watch(isProProvider);
    final user = ref.watch(currentUserProvider);
    // Watch the raw subscription state to know if it has actually loaded.
    // While loading, isProProvider returns false by default, which would
    // otherwise be mistaken for a genuine free→PRO transition every app start.
    final subscriptionLoaded = ref.watch(
      subscriptionProvider.select((s) => s.hasValue),
    );

    if (user == null) {
      _previousIsPro = null;
      _previousUserId = null;
      return const SyncState();
    }

    // Don't evaluate subscription transitions while still loading.
    if (!subscriptionLoaded) {
      return const SyncState();
    }

    final previous = _previousIsPro;
    final previousUserId = _previousUserId;

    _previousIsPro = isPro;
    _previousUserId = user.id;

    // If the user changed (account switch) do NOT migrate — the isPro change
    // reflects the new account's subscription, not an upgrade/downgrade of the
    // previous one. Each account's local data is already isolated by user_id.
    if (previousUserId != null && previousUserId != user.id) {
      return const SyncState();
    }

    if (previous != null && previous != isPro) {
      // Subscription status changed for the same user — run migration.
      // Return syncing state immediately so the repository providers keep
      // pointing at the source store while data is being transferred.
      _runMigration(wasPro: previous, userId: user.id);
      return const SyncState(status: SyncStatus.syncing);
    }

    // First build for this user on this device. If they're already PRO but
    // still have local transactions from a prior FREE period (e.g. the
    // subscription was already active when this app version first added
    // migration support, so no false→true transition was ever observed),
    // migrate those orphaned rows to Supabase now.
    if (previous == null && isPro) {
      final hasOrphanedLocalData = await _hasLocalData(user.id);
      if (hasOrphanedLocalData) {
        _runMigration(wasPro: false, userId: user.id);
        return const SyncState(status: SyncStatus.syncing);
      }
    }

    return const SyncState();
  }

  Future<bool> _hasLocalData(String userId) async {
    try {
      final tx = await LocalTransactionsRepository(userId: userId).getAllForUser();
      if (tx.isNotEmpty) return true;
      final recurring = await LocalRecurringTransactionsRepository(userId: userId)
          .getAllForUser();
      return recurring.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _runMigration({required bool wasPro, required String userId}) {
    Future(() async {
      try {
        if (_cancelled) return;

        final supabase = ref.read(supabaseClientProvider);

        // Descarta ops pendientes antes de migrar: los datos del store de
        // origen son la fuente de verdad y la migración los trasladará
        // íntegramente, por lo que la cola quedaría obsoleta.
        await SyncQueueRepository(userId: userId).clearAll();

        final service = TransactionSyncService(
          localTx: LocalTransactionsRepository(userId: userId),
          cloudTx: TransactionsRepository(supabase),
          localRecurring: LocalRecurringTransactionsRepository(userId: userId),
          cloudRecurring: RecurringTransactionsRepository(supabase),
        );

        if (wasPro) {
          // PRO expired: download cloud data to local
          await service.migrateToLocal();
        } else {
          // Upgraded to PRO: upload local data to cloud
          await service.migrateToCloud();
        }

        if (_cancelled) return;

        // State change triggers transactionsRepositoryProvider rebuild (it
        // watches syncProvider), which in turn rebuilds allTransactionsProvider.
        // No need to call ref.invalidate(allTransactionsProvider) directly —
        // doing so creates a circular dependency in Riverpod 3.x.
        state = const AsyncData(SyncState(status: SyncStatus.done));
      } catch (e, st) {
        if (_cancelled) return;
        unawaited(SentryService.captureException(e, stackTrace: st));
        state = AsyncData(SyncState(status: SyncStatus.error, error: e.toString()));
      }
    });
  }
}

final syncProvider =
    AsyncNotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
