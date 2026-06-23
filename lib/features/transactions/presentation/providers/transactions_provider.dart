import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/core/services/sentry_service.dart';
import 'package:expense_manager/l10n/app_localizations.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/initial_sync_service.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/sync_queue_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/presentation/providers/recurring_reminders_provider.dart';

// ── Period ────────────────────────────────────────────────────────────────────

enum TransactionPeriod { week, month, year }

extension TransactionPeriodX on TransactionPeriod {
  String l10nLabel(AppLocalizations l10n) {
    switch (this) {
      case TransactionPeriod.week:
        return l10n.periodWeek;
      case TransactionPeriod.month:
        return l10n.periodMonth;
      case TransactionPeriod.year:
        return l10n.periodYear;
    }
  }

  ({DateTime from, DateTime to}) get dateRange {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case TransactionPeriod.week:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return (from: startOfWeek, to: today);
      case TransactionPeriod.month:
        return (from: DateTime(now.year, now.month, 1), to: today);
      case TransactionPeriod.year:
        return (from: DateTime(now.year, 1, 1), to: today);
    }
  }
}

// ── Selected period ───────────────────────────────────────────────────────────

final selectedPeriodProvider =
    StateProvider<TransactionPeriod>((ref) => TransactionPeriod.month);

// ── Custom date range (overrides period when set) ─────────────────────────────

final customDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final effectiveDateRangeProvider =
    Provider<({DateTime from, DateTime to})>((ref) {
  final custom = ref.watch(customDateRangeProvider);
  if (custom != null) return (from: custom.start, to: custom.end);
  return ref.watch(selectedPeriodProvider).dateRange;
});

// ── All transactions (single source of truth) — cache-then-network ───────────
//
// Para usuarios PRO (Supabase):
//   1. Devuelve datos de SQLite inmediatamente (<100ms) si hay caché.
//   2. Lanza un refresh de Supabase en segundo plano.
//   3. Actualiza la UI silenciosamente cuando llegan datos frescos (sin spinner).
//
// Para usuarios free (SQLite local):
//   Consulta directa a SQLite, ya es rápida por naturaleza.

class AllTransactionsNotifier
    extends AsyncNotifier<List<TransactionModel>> {
  // Generación actual del build. Incrementa en cada rebuild para cancelar
  // refreshes de fondo que quedaron obsoletos.
  int _generation = 0;

  @override
  Future<List<TransactionModel>> build() async {
    _generation++;
    final generation = _generation;

    final range = ref.watch(effectiveDateRangeProvider);
    final isPro = ref.watch(isProProvider);
    final user = ref.watch(currentUserProvider);
    final repo = ref.watch(transactionsRepositoryProvider);

    // ── Usuarios PRO: caché SQLite primero ───────────────────────────────────
    if (isPro && user != null) {
      final localRepo = ref.read(localTransactionsRepositoryProvider);

      // Wrap in try/catch: on some Android devices the SQLite open can hang
      // (Keystore timeout) or fail after an update. Fall through to Supabase
      // so the shimmer doesn't spin forever.
      List<TransactionModel> cached = [];
      try {
        cached = await localRepo
            .getTransactions(from: range.from, to: range.to)
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        // Local DB unavailable — skip to cloud fetch below.
      }

      if (cached.isNotEmpty) {
        // Muestra la caché de forma instantánea y refresca Supabase en fondo.
        // Pasamos los ids ya leídos para evitar una segunda lectura de SQLite
        // dentro del refresh (el snapshot pre-fetch).
        _refreshInBackground(
          localRepo,
          range,
          generation,
          preFetchLocalIds: cached.map((t) => t.id).toSet(),
        );
        return cached;
      }

      // No local cache yet (first launch or new date range): fetch directly
      // from Supabase. We use the cloud-only repo here because the offline-aware
      // repo returned by transactionsRepositoryProvider only reads from SQLite.
      final cloudRepo = ref.read(cloudTxRepoForHydrationProvider);
      final fresh = await cloudRepo
          .getTransactions(from: range.from, to: range.to)
          .timeout(const Duration(seconds: 30));

      // Solo guardar en caché si InitialSyncService ya completó su hidratación.
      // Si no, InitialSyncService escribirá en SQLite cuando termine, evitando
      // así una carrera de escrituras concurrentes en el primer arranque.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('pro_hydrated_${user.id}') == true) {
        _saveToCache(localRepo, fresh);
      }
      return fresh;
    }

    // ── Usuarios free: SQLite local, ya es rápida ─────────────────────────────
    return repo.getTransactions(from: range.from, to: range.to);
  }

  // Refresca Supabase en segundo plano y actualiza la UI sin spinner.
  //
  // [preFetchLocalIds] es el snapshot de ids locales tomado ANTES del fetch al
  // cloud. Lo recibe ya calculado desde [build] (a partir de la caché que
  // acabamos de leer) para no repetir la lectura de SQLite. Cualquier tx local
  // que aparezca después (creada por el usuario mientras el fetch estaba en
  // vuelo) no estará en este set y por tanto se conservará en el merge —
  // evitando que deleteByDateRange la borre.
  void _refreshInBackground(
    LocalTransactionsRepository localRepo,
    ({DateTime from, DateTime to}) range,
    int generation, {
    required Set<String> preFetchLocalIds,
  }) {
    // Mantiene el provider vivo mientras dura el refresh de fondo.
    final keepAlive = ref.keepAlive();
    // Siempre usar el repo cloud para obtener datos frescos de Supabase,
    // igual que en el path sin caché. El repo offline-aware solo lee SQLite.
    final cloudRepo = ref.read(cloudTxRepoForHydrationProvider);

    Future(() async {
      try {
        final fresh = await cloudRepo.getTransactions(
          from: range.from,
          to: range.to,
        );

        // Si entre tanto hubo un rebuild (cambio de periodo, CRUD, etc.),
        // descartamos este resultado para no sobreescribir el estado nuevo.
        if (_generation != generation) return;

        // Preserve locally-created transactions not yet synced to the cloud
        // (offline creates or failed upserts sitting in the pending queue, o
        // txs creadas DURANTE este refresh). Lectura local best-effort: si la
        // caché es ilegible confiamos solo en el snapshot del cloud en vez de
        // descartar datos frescos.
        List<TransactionModel> localToKeep = [];
        try {
          final queue = ref.read(syncQueueRepositoryProvider);
          final pending = await queue.getPending();
          final pendingIds = pending.map((op) => op.entityId).toSet();
          final cloudIds = fresh.map((t) => t.id).toSet();

          final localInRange =
              await localRepo.getTransactions(from: range.from, to: range.to);
          localToKeep = localInRange.where((t) {
            if (cloudIds.contains(t.id)) return false;
            if (pendingIds.contains(t.id)) return true;
            return !preFetchLocalIds.contains(t.id);
          }).toList();
        } catch (e) {
          SentryService.addBreadcrumb(
              'localToKeep merge read failed: $e', category: 'sync');
        }

        final merged = [...fresh, ...localToKeep]
          ..sort((a, b) {
            final cmp = b.date.compareTo(a.date);
            return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
          });

        if (_generation != generation) return;

        // Actualización silenciosa de la UI con los datos frescos del cloud,
        // ANTES de persistir en caché: así un fallo de escritura local (p. ej.
        // SQLCipher/Keystore) nunca puede ocultar transacciones que ya existen
        // en Supabase.
        state = AsyncData(merged);

        // Sincroniza la caché como paso best-effort: reemplaza el rango
        // (datos frescos + locales conservados) de forma ATÓMICA. Hacerlo en
        // una sola transacción evita que un lector concurrente —p.ej. la
        // consulta del mes de budgetProgressProvider o del home widget— lea el
        // rango medio vacío entre el delete y el insert. Si falla, la UI ya
        // refleja el cloud y reintentaremos en el próximo refresh.
        try {
          await localRepo.replaceRange(range.from, range.to, merged);
        } catch (e) {
          SentryService.addBreadcrumb(
              'local cache sync write failed: $e', category: 'sync');
        }
      } catch (e) {
        // El refresh de fondo falló antes de obtener datos del cloud; el
        // usuario sigue viendo la caché sin ninguna interrupción.
        SentryService.addBreadcrumb(
            'background refresh failed: $e', category: 'sync');
      } finally {
        keepAlive.close();
      }
    });
  }

  void _saveToCache(
    LocalTransactionsRepository localRepo,
    List<TransactionModel> transactions,
  ) {
    // Best-effort: un fallo de escritura local no debe romper nada ni acabar
    // como unhandled-zone-error; la UI ya tiene los datos del cloud.
    Future(() async {
      try {
        await localRepo.insertAll(transactions);
      } catch (e) {
        SentryService.addBreadcrumb(
            'initial cache save failed: $e', category: 'sync');
      }
    });
  }
}

final allTransactionsProvider = AsyncNotifierProvider.autoDispose<
    AllTransactionsNotifier, List<TransactionModel>>(
  AllTransactionsNotifier.new,
);

// ── Summary (derived from allTransactionsProvider, no extra DB query) ─────────

final transactionsSummaryProvider =
    FutureProvider.autoDispose<TransactionsSummary>((ref) async {
  final transactions = await ref.watch(allTransactionsProvider.future);
  double income = 0;
  double expense = 0;
  for (final t in transactions) {
    if (t.type.isIncome) {
      income += t.amount;
    } else {
      expense += t.amount;
    }
  }
  return TransactionsSummary(income: income, expense: expense);
});

// ── Recent transactions (derived from allTransactionsProvider) ────────────────

final recentTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final all = await ref.watch(allTransactionsProvider.future);
  return all.take(3).toList();
});

// ── Category distribution (for pie/bar charts) ───────────────────────────────

final categoryDistributionProvider = FutureProvider.autoDispose
    .family<Map<String, double>, TransactionType>((ref, type) async {
  final transactions = await ref.watch(allTransactionsProvider.future);
  final map = <String, double>{};
  for (final t in transactions.where((t) => t.type == type)) {
    map[t.category] = (map[t.category] ?? 0) + t.amount;
  }
  return map;
});

// ── Category options (for the history filter menu) ───────────────────────────

/// Distinct categories present in the current period, sorted alphabetically.
/// Memoized so the list screen doesn't recompute (distinct + sort) on every
/// rebuild (e.g. multi-select toggles).
final transactionCategoryOptionsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final transactions = await ref.watch(allTransactionsProvider.future);
  return transactions.map((t) => t.category).toSet().toList()..sort();
});

// ── Notifier (CRUD) ───────────────────────────────────────────────────────────

class TransactionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> create(TransactionModel transaction) async {
    final repo = ref.read(transactionsRepositoryProvider);
    await repo.createTransaction(transaction);
    // Only invalidate the single source of truth; derived providers
    // (summary, recent, distribution) rebuild automatically.
    ref.invalidate(allTransactionsProvider);
    AnalyticsService.track(AnalyticsService.transactionCreated, {
      'type': transaction.type.name,
      'category': transaction.category,
      'is_recurring': transaction.recurringTransactionId != null,
    });
  }

  Future<void> update(TransactionModel transaction) async {
    await ref.read(transactionsRepositoryProvider).updateTransaction(transaction);
    ref.invalidate(allTransactionsProvider);
  }

  Future<void> delete(String id, {String? recurringTransactionId}) async {
    await ref.read(transactionsRepositoryProvider).deleteTransaction(id);
    if (recurringTransactionId != null) {
      await ref
          .read(recurringTransactionsRepositoryProvider)
          .deleteRecurring(recurringTransactionId);
      resyncRecurringReminders(ref);
    }
    ref.invalidate(allTransactionsProvider);
    AnalyticsService.track(AnalyticsService.transactionDeleted);
  }

  /// Orchestrates create/update of a transaction together with its optional
  /// recurring schedule. Extracted from the widget layer so the branching logic
  /// (new vs edit, recurring vs one-off, attach/detach/update schedule) can be
  /// unit-tested independently of the UI.
  Future<void> saveWithRecurrence({
    required TransactionModel transaction,
    required bool isEditing,
    required bool isRecurring,
    required RecurrenceType? recurrenceType,
    required String currency,
  }) async {
    final recurringRepo = ref.read(recurringTransactionsRepositoryProvider);

    if (isEditing) {
      final existingRecurringId = transaction.recurringTransactionId;
      if (isRecurring && recurrenceType != null) {
        final nextDate = nextRecurrenceDate(transaction.date, recurrenceType);
        if (existingRecurringId != null) {
          await recurringRepo.updateRecurring(
            id: existingRecurringId,
            amount: transaction.amount,
            type: transaction.type,
            category: transaction.category,
            subcategory: transaction.subcategory,
            description: transaction.description,
            recurrenceType: recurrenceType,
            nextOccurrence: nextDate,
          );
          await update(transaction);
        } else {
          final recurringId = await recurringRepo.createRecurring(
            amount: transaction.amount,
            type: transaction.type,
            category: transaction.category,
            subcategory: transaction.subcategory,
            description: transaction.description,
            recurrenceType: recurrenceType,
            nextOccurrence: nextDate,
          );
          await update(transaction.copyWith(recurringTransactionId: recurringId));
        }
      } else {
        if (existingRecurringId != null) {
          await recurringRepo.deleteRecurring(existingRecurringId);
        }
        await update(transaction.copyWith(recurringTransactionId: null));
      }
    } else {
      String? recurringId;
      if (isRecurring && recurrenceType != null) {
        final nextDate = nextRecurrenceDate(transaction.date, recurrenceType);
        recurringId = await recurringRepo.createRecurring(
          amount: transaction.amount,
          type: transaction.type,
          category: transaction.category,
          subcategory: transaction.subcategory,
          description: transaction.description,
          recurrenceType: recurrenceType,
          nextOccurrence: nextDate,
        );
      }
      // id/userId vacíos: OfflineAwareTransactionsRepository los estampa.
      // Usamos copyWith para no perder campos nuevos del modelo si se añaden.
      await create(
        transaction.copyWith(
          id: '',
          userId: '',
          createdAt: clock.now(),
          recurringTransactionId: recurringId,
          currency: currency,
        ),
      );
    }

    // Cualquier rama puede haber creado/editado/borrado una recurrente:
    // reprograma los recordatorios (no-op con el toggle off; nunca lanza).
    if (isRecurring || transaction.recurringTransactionId != null) {
      resyncRecurringReminders(ref);
    }
  }
}

final transactionsNotifierProvider =
    NotifierProvider<TransactionsNotifier, void>(TransactionsNotifier.new);
