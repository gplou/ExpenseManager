import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/subscription/subscription_state.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/presentation/providers/recurring_transactions_provider.dart';

import '../helpers/clock_helper.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<SubscriptionState> build() async => const SubscriptionState();
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  _FakeCurrencyNotifier(this._code);
  final String _code;

  @override
  Future<String> build() async => _code;
}

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockRecurringRepo extends Mock
    implements RecurringTransactionsRepositoryContract {}

class _FakeTxRepo implements TransactionsRepositoryContract {
  final List<TransactionModel> created = [];

  @override
  Future<TransactionModel> createTransaction(TransactionModel t) async {
    created.add(t);
    return t;
  }

  // Filtra por rango como el repo real: el dedup del catch-up consulta cada
  // fecha de ocurrencia individualmente.
  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) async =>
      created
          .where((t) => !t.date.isBefore(from) && !t.date.isAfter(to))
          .toList();

  @override
  Future<TransactionsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async =>
      const TransactionsSummary(income: 0, expense: 0);

  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) async => t;

  @override
  Future<void> deleteTransaction(String id) async {}

  @override
  Future<void> upsertTransaction(TransactionModel t) async {}
}

class _TrackingTxRepo implements TransactionsRepositoryContract {
  _TrackingTxRepo(this._inner, this._log);
  final _FakeTxRepo _inner;
  final List<String> _log;

  @override
  Future<TransactionModel> createTransaction(TransactionModel t) async {
    _log.add('create');
    return _inner.createTransaction(t);
  }

  @override
  Future<List<TransactionModel>> getTransactions({required DateTime from, required DateTime to}) =>
      _inner.getTransactions(from: from, to: to);
  @override
  Future<TransactionsSummary> getSummary({required DateTime from, required DateTime to}) =>
      _inner.getSummary(from: from, to: to);
  @override
  Future<TransactionModel> updateTransaction(TransactionModel t) => _inner.updateTransaction(t);
  @override
  Future<void> deleteTransaction(String id) => _inner.deleteTransaction(id);
  @override
  Future<void> upsertTransaction(TransactionModel t) => _inner.upsertTransaction(t);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

RecurringTransactionModel _recurring({
  String id = 'rec-1',
  double amount = 100.0,
  TransactionType type = TransactionType.expense,
  String category = 'Comida',
  String? subcategory,
  RecurrenceType recurrenceType = RecurrenceType.monthly,
  DateTime? nextOccurrence,
}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'user-1',
      amount: amount,
      type: type,
      category: category,
      subcategory: subcategory,
      recurrenceType: recurrenceType,
      nextOccurrence: nextOccurrence ?? DateTime(2024, 1, 15),
      createdAt: DateTime(2024, 1, 1),
    );

Future<ProviderContainer> _makeContainer({
  required _MockRecurringRepo recurringRepo,
  required TransactionsRepositoryContract txRepo,
  String currency = 'EUR',
}) async {
  final container = ProviderContainer(
    overrides: [
      subscriptionProvider.overrideWith(_FakeSubscriptionNotifier.new),
      currencyProvider.overrideWith(() => _FakeCurrencyNotifier(currency)),
      recurringTransactionsRepositoryProvider
          .overrideWith((ref) => recurringRepo),
      transactionsRepositoryProvider.overrideWith((ref) => txRepo),
    ],
  );
  // Resolve subscription before processRecurring reads it so hasValue is true
  // on the first build, preventing a reactive rebuild that causes test timeouts.
  await container.read(subscriptionProvider.future);
  return container;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockRecurringRepo recurringRepo;
  late _FakeTxRepo txRepo;

  // Por defecto: nextOccurrence = 15 ene 2024 y "hoy" = 20 ene 2024,
  // de modo que solo hay UNA ocurrencia vencida por recurrente.
  final defaultNow = DateTime(2024, 1, 20);

  setUp(() {
    recurringRepo = _MockRecurringRepo();
    txRepo = _FakeTxRepo();
    resetProcessedRecurringState();
    registerFallbackValue(
      TransactionModel(
        id: '',
        userId: '',
        amount: 0,
        type: TransactionType.expense,
        category: '',
        date: DateTime(2024),
        createdAt: DateTime(2024),
      ),
    );
  });

  group('processRecurringTransactionsProvider', () {
    test('does nothing when no due recurring transactions', () async {
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => []);

      await withFixedClockAsync(defaultNow, () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      expect(txRepo.created, isEmpty);
      verifyNever(() => recurringRepo.updateNextOccurrence(any(), any()));
    });

    test('creates a transaction for each due recurring', () async {
      final r = _recurring(id: 'rec-1', amount: 50, category: 'Comida');
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(defaultNow, () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      expect(txRepo.created.length, 1);
      final created = txRepo.created.first;
      expect(created.amount, 50.0);
      expect(created.category, 'Comida');
      expect(created.recurringTransactionId, 'rec-1');
    });

    test('uses nextOccurrence as the transaction date', () async {
      final dueDate = DateTime(2024, 3, 15);
      final r = _recurring(nextOccurrence: dueDate);
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(DateTime(2024, 3, 20), () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      expect(txRepo.created.first.date, dueDate);
    });

    test('advances nextOccurrence to the correct next date', () async {
      final dueDate = DateTime(2024, 3, 15);
      final r = _recurring(
        id: 'rec-1',
        nextOccurrence: dueDate,
        recurrenceType: RecurrenceType.monthly,
      );
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(DateTime(2024, 3, 20), () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      final captured = verify(() =>
              recurringRepo.updateNextOccurrence('rec-1', captureAny()))
          .captured;
      final nextDate = captured.first as DateTime;
      // Monthly: Mar 15 → Apr 15
      expect(nextDate, DateTime(2024, 4, 15));
    });

    test('advances nextOccurrence BEFORE creating transaction — prevents duplicates on crash', () async {
      final callOrder = <String>[];

      when(() => recurringRepo.getDueRecurring())
          .thenAnswer((_) async => [_recurring(id: 'rec-1')]);
      when(() => recurringRepo.updateNextOccurrence(any(), any())).thenAnswer((_) async {
        callOrder.add('advance');
      });

      final trackingTxRepo = _TrackingTxRepo(txRepo, callOrder);
      await withFixedClockAsync(defaultNow, () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: trackingTxRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      expect(
        callOrder,
        ['advance', 'create'],
        reason: 'nextOccurrence must be advanced before the transaction is '
            'created so that a crash between the two steps cannot cause '
            'duplicate transactions on the next session.',
      );
    });

    test('second run in same session is a no-op (prevents duplicate cloud writes)', () async {
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [
            _recurring(id: 'rec-1'),
          ]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(defaultNow, () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        // First run processes rec-1 and creates the transaction.
        await container.read(processRecurringTransactionsProvider.future);
        expect(txRepo.created.length, 1);

        // Second run (simulates pull-to-refresh in the same session).
        // _processedThisSession already contains 'rec-1' so it must be a no-op.
        container.invalidate(processRecurringTransactionsProvider);
        await container.read(processRecurringTransactionsProvider.future);
      });

      expect(
        txRepo.created.length,
        1,
        reason: 'Same-session re-run must not create duplicate transactions.',
      );
    });

    test('processes multiple due recurring transactions', () async {
      final r1 = _recurring(id: 'rec-1', amount: 100, category: 'Comida');
      final r2 = _recurring(id: 'rec-2', amount: 200, category: 'Transporte');
      when(() => recurringRepo.getDueRecurring())
          .thenAnswer((_) async => [r1, r2]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(defaultNow, () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      expect(txRepo.created.length, 2);
      expect(txRepo.created.map((t) => t.category).toList(),
          containsAll(['Comida', 'Transporte']));
      verify(() => recurringRepo.updateNextOccurrence(any(), any()))
          .called(2);
    });

    test('transaction type matches recurring type', () async {
      final r = _recurring(type: TransactionType.income, category: 'Salario');
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(defaultNow, () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      expect(txRepo.created.first.type, TransactionType.income);
    });
  });

  group('catch-up de ocurrencias vencidas', () {
    test('materializes ALL overdue occurrences, not just the first', () async {
      // Mensual con vencimiento 15 ene y "hoy" 20 abr → 4 ocurrencias vencidas.
      final r = _recurring(
        id: 'rec-1',
        nextOccurrence: DateTime(2024, 1, 15),
        recurrenceType: RecurrenceType.monthly,
      );
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(DateTime(2024, 4, 20), () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      expect(
        txRepo.created.map((t) => t.date).toList(),
        [
          DateTime(2024, 1, 15),
          DateTime(2024, 2, 15),
          DateTime(2024, 3, 15),
          DateTime(2024, 4, 15),
        ],
        reason: 'Tras 3 meses sin abrir la app, una recurrente mensual debe '
            'generar todas las ocurrencias perdidas, no solo la primera.',
      );

      // next_occurrence final queda en el futuro (15 may).
      final captured = verify(() =>
              recurringRepo.updateNextOccurrence('rec-1', captureAny()))
          .captured;
      expect(captured.last, DateTime(2024, 5, 15));
    });

    test('preserves subcategory and stamps the global currency', () async {
      final r = _recurring(
        id: 'rec-1',
        category: 'Comida',
        subcategory: 'Supermercado',
      );
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(defaultNow, () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
          currency: 'USD',
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      final created = txRepo.created.single;
      expect(created.subcategory, 'Supermercado',
          reason: 'La subcategoría de la recurrente no debe perderse.');
      expect(created.currency, 'USD',
          reason: 'La ocurrencia debe heredar la divisa global, no EUR fijo.');
    });

    test('caps catch-up at 36 occurrences (corrupt/ancient next_occurrence)', () async {
      // Semanal con 5 años de atraso → cientos de ocurrencias teóricas.
      final r = _recurring(
        id: 'rec-1',
        nextOccurrence: DateTime(2019, 1, 15),
        recurrenceType: RecurrenceType.weekly,
      );
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(DateTime(2024, 1, 15), () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      expect(txRepo.created.length, 36);
    });

    test('dedup skips occurrences that already exist mid catch-up', () async {
      // La ocurrencia de febrero ya existe (p.ej. creada por una sesión
      // interrumpida); el catch-up debe saltarla sin duplicar.
      txRepo.created.add(
        TransactionModel(
          id: 'existing-feb',
          userId: 'user-1',
          amount: 100,
          type: TransactionType.expense,
          category: 'Comida',
          date: DateTime(2024, 2, 15),
          createdAt: DateTime(2024, 2, 15),
          recurringTransactionId: 'rec-1',
        ),
      );

      final r = _recurring(
        id: 'rec-1',
        nextOccurrence: DateTime(2024, 1, 15),
        recurrenceType: RecurrenceType.monthly,
      );
      when(() => recurringRepo.getDueRecurring()).thenAnswer((_) async => [r]);
      when(() => recurringRepo.updateNextOccurrence(any(), any()))
          .thenAnswer((_) async {});

      await withFixedClockAsync(DateTime(2024, 4, 20), () async {
        final container = await _makeContainer(
          recurringRepo: recurringRepo,
          txRepo: txRepo,
        );
        addTearDown(container.dispose);

        await container.read(processRecurringTransactionsProvider.future);
      });

      final febOccurrences =
          txRepo.created.where((t) => t.date == DateTime(2024, 2, 15));
      expect(febOccurrences.length, 1,
          reason: 'La ocurrencia ya existente no debe duplicarse.');
      // ene + feb(preexistente) + mar + abr = 4 filas en total.
      expect(txRepo.created.length, 4);
    });
  });
}
