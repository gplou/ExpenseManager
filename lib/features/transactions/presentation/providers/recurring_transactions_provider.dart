import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'transactions_provider.dart';

// IDs of recurring transactions already processed this session.
// Using a Set (not a Riverpod provider) to avoid the Riverpod restriction
// against modifying providers during initialization.
final _processedThisSession = <String>{};

/// Tope de ocurrencias materializadas por recurrente y sesión durante el
/// catch-up (≈3 años mensuales / 8 meses semanales). Protege contra
/// `next_occurrence` corruptos o absurdamente antiguos.
const _maxCatchUpOccurrences = 36;

/// Resets the session-level processing state. Call in tests between runs.
@visibleForTesting
void resetProcessedRecurringState() => _processedThisSession.clear();

/// Procesa las transacciones recurrentes pendientes al abrir la app.
/// Al ser un FutureProvider sin autoDispose, se ejecuta una vez por sesión
/// y solo se repite si se invalida explícitamente (ej. al hacer pull-to-refresh).
final processRecurringTransactionsProvider = FutureProvider<void>((ref) async {
  // Wait for the subscription to resolve before processing. Without this guard,
  // the provider runs during the loading window where isProProvider is still
  // false, causing recurringTransactionsRepositoryProvider to return the LOCAL
  // repo instead of the cloud one. That makes updateNextOccurrence write only
  // to SQLite — leaving next_occurrence stale in Supabase — and the next
  // session creates a duplicate transaction for the same date.
  // Using ref.watch here causes the FutureProvider to rebuild automatically
  // once the subscription resolves, so no manual invalidation is needed.
  final subscriptionLoaded =
      ref.watch(subscriptionProvider.select((s) => s.hasValue));
  if (!subscriptionLoaded) return;

  final recurringRepo = ref.read(recurringTransactionsRepositoryProvider);
  final txRepo = ref.read(transactionsRepositoryProvider);

  final due = await recurringRepo.getDueRecurring();
  // Filter out IDs already processed in this session (guards against concurrent
  // runs triggered by pull-to-refresh while a previous run is still in flight).
  final toProcess = due.where((r) => !_processedThisSession.contains(r.id)).toList();
  if (toProcess.isEmpty) return;

  // Divisa global actual: las ocurrencias materializadas la heredan (la divisa
  // es display-only en toda la app; ver currency_provider.dart).
  final currency = await ref.read(currencyProvider.future);

  for (final r in toProcess) {
    // Mark as processed BEFORE any async operation so that a concurrent run
    // starting after this point will skip this recurring transaction.
    _processedThisSession.add(r.id);

    // Catch-up: materializa TODAS las ocurrencias vencidas, no solo la primera
    // (si la app llevaba 3 meses sin abrirse, una recurrente mensual genera 3).
    var occurrence = r.nextOccurrence;
    final today = clock.now();
    var iterations = 0;
    while (!occurrence.isAfter(today) &&
        iterations++ < _maxCatchUpOccurrences) {
      // Avanzar next_occurrence ANTES de crear la transacción: si el proceso
      // se interrumpe entre los dos pasos, la próxima sesión no vuelve a crear
      // la misma transacción (evita duplicados persistentes en Supabase).
      final next = nextRecurrenceDate(occurrence, r.recurrenceType);
      await recurringRepo.updateNextOccurrence(r.id, next);

      // Defensive dedup: skip creation if a transaction for this recurring+date
      // already exists. Guards against stale next_occurrence left in Supabase by
      // a prior interrupted session (e.g. updateNextOccurrence hit local-only repo
      // before the subscription-loading guard was added).
      final existing = await txRepo.getTransactions(
        from: occurrence,
        to: occurrence,
      );
      if (!existing.any((t) => t.recurringTransactionId == r.id)) {
        await txRepo.createTransaction(
          TransactionModel(
            id: '',
            userId: '',
            amount: r.amount,
            type: r.type,
            category: r.category,
            subcategory: r.subcategory,
            description: r.description,
            date: occurrence,
            createdAt: clock.now(),
            recurringTransactionId: r.id,
            currency: currency,
          ),
        );
      }
      occurrence = next;
    }
  }

  // Refrescar la única fuente de verdad; summary/recent derivan de ella.
  ref.invalidate(allTransactionsProvider);
});
