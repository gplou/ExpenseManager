import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/recurring_transactions_provider.dart';

import '../../helpers/clock_helper.dart';
import '../../helpers/mocks.dart';
import '../../helpers/provider_container_helper.dart';

RecurringTransactionModel _rec(String id, DateTime next, {double amount = 10}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'u1',
      amount: amount,
      type: TransactionType.expense,
      category: 'Ocio',
      recurrenceType: RecurrenceType.monthly,
      nextOccurrence: next,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late MockRecurringTransactionsRepository repo;

  setUp(() {
    repo = MockRecurringTransactionsRepository();
  });

  Future<List<RecurringTransactionModel>> read(
    List<RecurringTransactionModel> all,
  ) async {
    when(() => repo.getAllForUser()).thenAnswer((_) async => all);
    final container = makeContainer([
      recurringTransactionsRepositoryProvider.overrideWithValue(repo),
      // El provider espera al catch-up antes de listar; aquí no interesa.
      processRecurringTransactionsProvider.overrideWith((_) async {}),
    ]);
    return container.read(upcomingRecurringProvider.future);
  }

  test('lista solo lo que vence dentro de la ventana, en orden', () async {
    await withFixedClock(DateTime(2026, 9, 15), () async {
      final result = await read([
        _rec('lejos', DateTime(2026, 11, 1)),
        _rec('pronto', DateTime(2026, 9, 20)),
        _rec('medio', DateTime(2026, 10, 5)),
      ]);

      expect(result.map((r) => r.id), ['pronto', 'medio']);
    });
  });

  test('incluye lo que vence hoy', () async {
    await withFixedClock(DateTime(2026, 9, 15, 23, 30), () async {
      // Vence hoy pero a una hora ya pasada: sigue contando como próximo, no
      // se puede perder un recibo por la hora del día.
      final result = await read([_rec('hoy', DateTime(2026, 9, 15, 8))]);
      expect(result.map((r) => r.id), ['hoy']);
    });
  });

  test('excluye lo ya vencido', () async {
    await withFixedClock(DateTime(2026, 9, 15), () async {
      final result = await read([_rec('ayer', DateTime(2026, 9, 14))]);
      expect(result, isEmpty);
    });
  });

  test('sin recurrentes devuelve lista vacía', () async {
    await withFixedClock(DateTime(2026, 9, 15), () async {
      expect(await read([]), isEmpty);
    });
  });
}
