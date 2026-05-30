import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../subscription/subscription_provider.dart';
import '../../data/initial_sync_service.dart';
import '../../data/local_transactions_repository.dart';
import '../../data/recurring_transactions_repository.dart';
import '../../data/sync_queue_repository.dart';
import '../../data/transactions_repository.dart';
import '../../domain/transaction_model.dart';
import '../../domain/transactions_repository_contract.dart';

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
      final localRepo = LocalTransactionsRepository(userId: user.id);

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
        _refreshInBackground(localRepo, range, generation);
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
  void _refreshInBackground(
    LocalTransactionsRepository localRepo,
    ({DateTime from, DateTime to}) range,
    int generation,
  ) {
    // Mantiene el provider vivo mientras dura el refresh de fondo.
    final keepAlive = ref.keepAlive();
    // Siempre usar el repo cloud para obtener datos frescos de Supabase,
    // igual que en el path sin caché. El repo offline-aware solo lee SQLite.
    final cloudRepo = ref.read(cloudTxRepoForHydrationProvider);

    Future(() async {
      try {
        // Snapshot de IDs locales ANTES del fetch al cloud. Cualquier tx local
        // que aparezca después (creada por el usuario mientras el fetch estaba
        // en vuelo) se conservará aunque no esté en cloudIds ni en pendingIds.
        // Sin este snapshot la creación se borraba al hacer deleteByDateRange.
        // Lectura best-effort: si SQLite falla seguimos con un snapshot vacío
        // en lugar de abortar el refresh y perder los datos frescos del cloud.
        Set<String> preFetchLocalIds = {};
        try {
          preFetchLocalIds = (await localRepo.getTransactions(
            from: range.from,
            to: range.to,
          ))
              .map((t) => t.id)
              .toSet();
        } catch (_) {}

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
          final queue = SyncQueueRepository(userId: localRepo.userId);
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
        } catch (_) {}

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

        // Sincroniza la caché como paso best-effort: elimina el rango y
        // reinserta datos frescos + locales conservados. Si falla, la UI ya
        // refleja el cloud y reintentaremos en el próximo refresh.
        try {
          await localRepo.deleteByDateRange(range.from, range.to);
          await localRepo.insertAll(merged);
        } catch (_) {}
      } catch (_) {
        // El refresh de fondo falló antes de obtener datos del cloud; el
        // usuario sigue viendo la caché sin ninguna interrupción.
      } finally {
        keepAlive.close();
      }
    });
  }

  void _saveToCache(
    LocalTransactionsRepository localRepo,
    List<TransactionModel> transactions,
  ) {
    Future(() => localRepo.insertAll(transactions));
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

// ── Notifier (CRUD) ───────────────────────────────────────────────────────────

class TransactionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> create(TransactionModel transaction) async {
    final repo = ref.read(transactionsRepositoryProvider);
    debugPrint('TransactionsNotifier.create: repo=${repo.runtimeType}');
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
    }
    ref.invalidate(allTransactionsProvider);
    AnalyticsService.track(AnalyticsService.transactionDeleted);
  }
}

final transactionsNotifierProvider =
    NotifierProvider<TransactionsNotifier, void>(TransactionsNotifier.new);
