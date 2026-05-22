import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

import '../../../helpers/clock_helper.dart';

class _TestRepo extends RecurringTransactionsRepository {
  _TestRepo(super.client, this._userId);
  final String _userId;
  @override
  String get userId => _userId;
}

Map<String, dynamic> _row({
  required String id,
  String userId = 'user-1',
  double amount = 10,
  String type = 'expense',
  String category = 'Comida',
  String? subcategory,
  String? description,
  String recurrenceType = 'monthly',
  required String nextOccurrence,
  String createdAt = '2026-01-01T00:00:00Z',
}) =>
    {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'recurrence_type': recurrenceType,
      'next_occurrence': nextOccurrence,
      'created_at': createdAt,
    };

void main() {
  late MockSupabaseHttpClient mockHttp;
  late SupabaseClient supabase;
  late _TestRepo repo;

  setUp(() {
    mockHttp = MockSupabaseHttpClient();
    supabase = SupabaseClient(
      'https://mock.supabase.co',
      'fakeAnonKey',
      httpClient: mockHttp,
    );
    repo = _TestRepo(supabase, 'user-1');
  });

  tearDown(() {
    mockHttp.reset();
    mockHttp.close();
  });

  // ── getDueRecurring ──────────────────────────────────────────────────────

  group('getDueRecurring', () {
    test('returns rows scoped to the user', () async {
      await supabase.from('recurring_transactions').insert([
        _row(id: 'r1', userId: 'user-1', nextOccurrence: '2026-01-01'),
        _row(id: 'r-other', userId: 'user-2', nextOccurrence: '2026-01-01'),
      ]);

      final result = await withFixedClockAsync(
        DateTime(2026, 5, 21),
        () => repo.getDueRecurring(),
      );

      expect(result.map((r) => r.id).toList(), ['r1']);
    });

    test('returns an empty list when nothing is due', () async {
      final result = await repo.getDueRecurring();
      expect(result, isEmpty);
    });
  });

  // ── getById ──────────────────────────────────────────────────────────────

  group('getById', () {
    test('returns the matching row mapped to the model', () async {
      await supabase.from('recurring_transactions').insert(_row(
            id: 'r1',
            amount: 99,
            recurrenceType: 'weekly',
            nextOccurrence: '2026-06-01',
          ));

      final result = await repo.getById('r1');

      expect(result, isNotNull);
      expect(result!.id, 'r1');
      expect(result.amount, 99);
      expect(result.recurrenceType, RecurrenceType.weekly);
      expect(result.nextOccurrence, DateTime(2026, 6, 1));
    });

    test('returns null when id is not found', () async {
      final result = await repo.getById('nope');
      expect(result, isNull);
    });

    test('returns null when id matches another user', () async {
      await supabase.from('recurring_transactions').insert(
            _row(id: 'r1', userId: 'user-2', nextOccurrence: '2026-06-01'),
          );
      final result = await repo.getById('r1');
      expect(result, isNull);
    });
  });

  // ── getAllForUser ────────────────────────────────────────────────────────

  group('getAllForUser', () {
    test('returns all rows for the user, regardless of next_occurrence',
        () async {
      await supabase.from('recurring_transactions').insert([
        _row(id: 'r1', nextOccurrence: '2026-01-01'),
        _row(id: 'r2', nextOccurrence: '2027-01-01'),
        _row(id: 'r-other', userId: 'user-2', nextOccurrence: '2026-01-01'),
      ]);

      final result = await repo.getAllForUser();

      expect(result.map((r) => r.id).toList()..sort(), ['r1', 'r2']);
    });
  });

  // ── updateRecurring ──────────────────────────────────────────────────────

  group('updateRecurring', () {
    test('updates the row matching id + user_id', () async {
      await supabase.from('recurring_transactions').insert(_row(
            id: 'r1',
            amount: 10,
            nextOccurrence: '2026-01-01',
          ));

      await repo.updateRecurring(
        id: 'r1',
        amount: 25,
        type: TransactionType.income,
        category: 'Salario',
        recurrenceType: RecurrenceType.annual,
        nextOccurrence: DateTime(2027, 1, 1),
      );

      final row = (await supabase.from('recurring_transactions').select()).single;
      expect(row['amount'], 25);
      expect(row['type'], 'income');
      expect(row['category'], 'Salario');
      expect(row['recurrence_type'], 'annual');
      expect(row['next_occurrence'], '2027-01-01');
    });
  });

  // ── updateNextOccurrence ─────────────────────────────────────────────────

  group('updateNextOccurrence', () {
    test('writes the new next_occurrence date without touching other fields',
        () async {
      await supabase.from('recurring_transactions').insert(_row(
            id: 'r1',
            amount: 42,
            category: 'X',
            nextOccurrence: '2026-01-01',
          ));

      await repo.updateNextOccurrence('r1', DateTime(2026, 2, 1));

      final row = (await supabase.from('recurring_transactions').select()).single;
      expect(row['next_occurrence'], '2026-02-01');
      expect(row['amount'], 42);
      expect(row['category'], 'X');
    });
  });

  // ── deleteRecurring ──────────────────────────────────────────────────────

  group('deleteRecurring', () {
    test('removes the row and nulls out linked transactions', () async {
      await supabase.from('recurring_transactions').insert(_row(
            id: 'r1',
            nextOccurrence: '2026-01-01',
          ));
      await supabase.from('transactions').insert([
        {
          'id': 'tx-1',
          'user_id': 'user-1',
          'amount': 10,
          'type': 'expense',
          'category': 'C',
          'date': '2026-03-15',
          'created_at': '2026-03-15T00:00:00Z',
          'currency': 'EUR',
          'recurring_transaction_id': 'r1',
        },
      ]);

      await repo.deleteRecurring('r1');

      final recRows = await supabase.from('recurring_transactions').select();
      expect(recRows, isEmpty);

      final txRows = await supabase.from('transactions').select();
      expect(txRows.single['recurring_transaction_id'], isNull);
    });
  });

  // ── upsertRecurring ──────────────────────────────────────────────────────

  group('upsertRecurring', () {
    test('inserts when id does not exist', () async {
      final model = RecurringTransactionModel(
        id: 'r-new',
        userId: 'user-1',
        amount: 5,
        type: TransactionType.expense,
        category: 'C',
        recurrenceType: RecurrenceType.monthly,
        nextOccurrence: DateTime(2026, 4, 1),
        createdAt: clock.now(),
      );

      await repo.upsertRecurring(model);

      final rows = await supabase.from('recurring_transactions').select();
      expect(rows.single['id'], 'r-new');
      expect(rows.single['next_occurrence'], '2026-04-01');
    });
  });
}
