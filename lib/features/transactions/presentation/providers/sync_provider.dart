import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/core/services/sentry_service.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/budgets/data/budgets_repository.dart';
import 'package:expense_manager/features/budgets/data/budgets_sync_service.dart';
import 'package:expense_manager/features/budgets/data/local_budgets_repository.dart';
import 'package:expense_manager/features/budgets/domain/budgets_repository_contract.dart';
import 'package:expense_manager/features/transactions/data/hydration_flag.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/sync_queue_repository.dart';
import 'package:expense_manager/features/transactions/data/transaction_sync_service.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';

/// Cloud repos used exclusively by the FREE↔PRO migration ([SyncNotifier]).
/// Exposed as providers (mirroring the hydration repos in
/// initial_sync_service.dart) so tests can override them with in-memory fakes
/// instead of stubbing the whole Supabase client.
final cloudTxRepoForMigrationProvider =
    Provider<TransactionsRepositoryContract>(
  (ref) => TransactionsRepository(ref.read(supabaseClientProvider)),
);

final cloudRecurringRepoForMigrationProvider =
    Provider<RecurringTransactionsRepositoryContract>(
  (ref) => RecurringTransactionsRepository(ref.read(supabaseClientProvider)),
);

/// Cloud budgets repo usado exclusivamente por la migración FREE↔PRO.
/// Expuesto como provider para que los tests lo sustituyan por un fake.
final cloudBudgetsRepoForMigrationProvider = Provider<CloudBudgetsRepo>(
  (ref) => SupabaseBudgetsRepository(ref.read(supabaseClientProvider)),
);

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

  /// Cadena serial de migraciones. Toggles rápidos PRO↔FREE re-ejecutan
  /// [build] varias veces; sin serializar, dos `_runMigration` corrían en
  /// paralelo (uno subiendo a la nube, otro borrándola) y se corrompían los
  /// datos. Encadenamos sobre este Future para que cada migración espere a la
  /// anterior. La reevaluación del plan real dentro de [_runMigration] descarta
  /// las que hayan quedado obsoletas.
  Future<void> _migrationChain = Future.value();

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

    // Mantenimiento al operar como FREE: las escrituras FREE son solo locales,
    // así que el store local deja de ser un espejo puro de la nube. Invalidar
    // el flag de hidratación mantiene su invariante (ver [HydrationFlag]) y
    // descarta los create/update pendientes de la cola — el local ya los
    // refleja y la próxima subida FREE→PRO (aditiva) los cubrirá; dejarlos
    // encolados permitiría que un flush futuro re-aplicara versiones obsoletas.
    // Las lápidas de borrado se conservan siempre.
    var wasHydratedMirror = false;
    if (!isPro) {
      try {
        wasHydratedMirror = await HydrationFlag.isSet(user.id);
        await HydrationFlag.clear(user.id);
        await SyncQueueRepository(userId: user.id).clearUpsertOps();
      } catch (_) {
        // Best-effort: sin prefs/DB no bloqueamos la evaluación del estado.
      }
    }

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

    // First build for this user on this device.
    if (previous == null) {
      if (isPro) {
        // PRO con datos locales NO hidratados: son filas huérfanas de un
        // periodo FREE (p. ej. la suscripción se activó/renovó con la app
        // cerrada, así que nunca se observó la transición false→true) —
        // súbelas a Supabase ahora. Si el flag de hidratación está activo, lo
        // local es el espejo de la nube de un PRO estable: re-migrarlo en cada
        // arranque sería una subida+descarga completa e innecesaria del
        // histórico.
        final hydrated = await HydrationFlag.isSet(user.id);
        if (!hydrated && await _hasLocalData(user.id)) {
          _runMigration(wasPro: false, userId: user.id);
          return const SyncState(status: SyncStatus.syncing);
        }
      } else if (wasHydratedMirror) {
        // FREE cuyo flag de hidratación estaba activo: era PRO en este
        // dispositivo y la expiración se detectó con la app cerrada (nunca se
        // observó la transición true→false). Ejecuta la misma migración
        // PRO→FREE que el downgrade en caliente para traer las filas creadas
        // desde otros dispositivos. Si falla (p. ej. sin red) no pasa nada: el
        // espejo local ya está completo y el flag quedó limpio, así que no se
        // reintenta en cada arranque.
        _runMigration(wasPro: true, userId: user.id);
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
      if (recurring.isNotEmpty) return true;
      final budgets =
          await LocalBudgetsRepository(userId: userId).getAllForUser();
      return budgets.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _runMigration({required bool wasPro, required String userId}) {
    // Encadena sobre la migración anterior para que nunca corran dos a la vez.
    _migrationChain = _migrationChain.then((_) async {
      try {
        if (_cancelled) return;

        // Reevalúa el plan real justo antes de ejecutar: si entre que se encoló
        // esta migración y ahora el usuario volvió a cambiar de plan, la
        // dirección (wasPro) ya no refleja la realidad. Saltamos esta y dejamos
        // que la siguiente en cola (encolada por el último cambio) reconcilie.
        final isProNow = ref.read(isProProvider);
        if (wasPro == isProNow) {
          // wasPro==true & sigue PRO  → no hubo bajada real (o ya se revirtió).
          // wasPro==false & sigue FREE → no hubo subida real (o ya se revirtió).
          // En ambos casos esta migración es obsoleta. Salimos de `syncing`
          // para que los repos vuelvan a apuntar al store correcto.
          if (!_cancelled) state = const AsyncData(SyncState());
          return;
        }

        final queue = SyncQueueRepository(userId: userId);

        final service = TransactionSyncService(
          localTx: LocalTransactionsRepository(userId: userId),
          cloudTx: ref.read(cloudTxRepoForMigrationProvider),
          localRecurring: LocalRecurringTransactionsRepository(userId: userId),
          cloudRecurring: ref.read(cloudRecurringRepoForMigrationProvider),
          queue: queue,
        );

        final budgetsService = BudgetsSyncService(
          local: LocalBudgetsRepository(userId: userId),
          cloud: ref.read(cloudBudgetsRepoForMigrationProvider),
        );

        if (wasPro) {
          // PRO expired: download cloud data to local, sin tocar la nube ni la
          // cola. Las lápidas de borrado pendientes (borrados offline que la
          // nube aún no vio) se conservan: migrateToLocal filtra esas filas de
          // la descarga para que no resuciten, y la próxima migración FREE→PRO
          // las aplicará contra la nube. Los create/update pendientes ya los
          // descartó build() al confirmarse FREE (el local los refleja).
          await service.migrateToLocal();
          await budgetsService.migrateToLocal();
        } else {
          // Upgraded to PRO: sube los datos locales a la nube y reproduce las
          // lápidas de borrado del periodo FREE, de modo que las transacciones
          // borradas siendo FREE se eliminen también de Supabase (podrían
          // seguir ahí de un periodo PRO anterior). Se leen ANTES de migrar y la
          // cola se limpia solo DESPUÉS del éxito, para que un fallo a medias se
          // reintente con las lápidas intactas. Las ops create/update pendientes
          // se descartan: el store local ya las refleja y se sube entero.
          final deletedIds = await queue.pendingDeleteEntityIds();
          final deletedRecurringIds =
              await queue.pendingRecurringDeleteEntityIds();
          await service.migrateToCloud(
            deletedTransactionIds: deletedIds,
            deletedRecurringIds: deletedRecurringIds,
          );
          await budgetsService.migrateToCloud();
          await queue.clearAll();

          // migrateToCloud vació el espejo local tras subir a la nube. Forzamos
          // la rehidratación limpiando el flag (normalmente ya está limpio: los
          // builds FREE lo invalidan): si quedara puesto, InitialSyncService no
          // repoblaría el espejo, dejando getTransactions (y por tanto el gasto
          // de cada presupuesto) en 0 hasta el siguiente reinicio. El listener
          // de InitialSyncService dispara _tryHydrate al pasar isSyncing→false.
          await HydrationFlag.clear(userId);
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
