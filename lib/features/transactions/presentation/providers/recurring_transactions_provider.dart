import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/recurring_transactions_repository.dart';
import '../../data/transactions_repository.dart';
import '../../domain/recurring_transaction_model.dart';
import '../../domain/transaction_model.dart';
import 'transactions_provider.dart';

// IDs of recurring transactions already processed this session.
// Using a Set (not a Riverpod provider) to avoid the Riverpod restriction
// against modifying providers during initialization.
final _processedThisSession = <String>{};

/// Resets the session-level processing state. Call in tests between runs.
@visibleForTesting
void resetProcessedRecurringState() => _processedThisSession.clear();

/// Procesa las transacciones recurrentes pendientes al abrir la app.
/// Al ser un FutureProvider sin autoDispose, se ejecuta una vez por sesión
/// y solo se repite si se invalida explícitamente (ej. al hacer pull-to-refresh).
final processRecurringTransactionsProvider = FutureProvider<void>((ref) async {
  final recurringRepo = ref.read(recurringTransactionsRepositoryProvider);
  final txRepo = ref.read(transactionsRepositoryProvider);

  final due = await recurringRepo.getDueRecurring();
  // Filter out IDs already processed in this session (guards against concurrent
  // runs triggered by pull-to-refresh while a previous run is still in flight).
  final toProcess = due.where((r) => !_processedThisSession.contains(r.id)).toList();
  if (toProcess.isEmpty) return;

  for (final r in toProcess) {
    // Mark as processed BEFORE any async operation so that a concurrent run
    // starting after this point will skip this recurring transaction.
    _processedThisSession.add(r.id);

    // Avanzar next_occurrence ANTES de crear la transacción: si el proceso
    // se interrumpe entre los dos pasos, la próxima sesión no vuelve a crear
    // la misma transacción (evita duplicados persistentes en Supabase).
    final next = nextRecurrenceDate(r.nextOccurrence, r.recurrenceType);
    await recurringRepo.updateNextOccurrence(r.id, next);

    // Crear la transacción real para la fecha de vencimiento
    await txRepo.createTransaction(
      TransactionModel(
        id: '',
        userId: '',
        amount: r.amount,
        type: r.type,
        category: r.category,
        description: r.description,
        date: r.nextOccurrence,
        createdAt: DateTime.now(),
        recurringTransactionId: r.id,
      ),
    );
  }

  // Refrescar los datos del dashboard
  ref.invalidate(transactionsSummaryProvider);
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(allTransactionsProvider);
});
