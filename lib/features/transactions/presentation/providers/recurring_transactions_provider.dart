import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/recurring_transactions_repository.dart';
import '../../data/transactions_repository.dart';
import '../../domain/recurring_transaction_model.dart';
import '../../domain/transaction_model.dart';
import 'transactions_provider.dart';

/// Procesa las transacciones recurrentes pendientes al abrir la app.
/// Al ser un FutureProvider sin autoDispose, se ejecuta una vez por sesión
/// y solo se repite si se invalida explícitamente (ej. al hacer pull-to-refresh).
final processRecurringTransactionsProvider = FutureProvider<void>((ref) async {
  final recurringRepo = ref.read(recurringTransactionsRepositoryProvider);
  final txRepo = ref.read(transactionsRepositoryProvider);

  final due = await recurringRepo.getDueRecurring();
  if (due.isEmpty) return;

  for (final r in due) {
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
      ),
    );

    // Avanzar next_occurrence al siguiente ciclo
    final next = nextRecurrenceDate(r.nextOccurrence, r.recurrenceType);
    await recurringRepo.updateNextOccurrence(r.id, next);
  }

  // Refrescar los datos del dashboard
  ref.invalidate(transactionsSummaryProvider);
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(allTransactionsProvider);
});
