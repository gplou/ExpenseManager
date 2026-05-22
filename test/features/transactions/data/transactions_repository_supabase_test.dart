import 'package:flutter_test/flutter_test.dart';
import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

/// Subclass that bypasses [AuthenticatedRepository.userId] (which would
/// normally read `client.auth.currentUser` — null in tests) and returns
/// a fixed test user id instead.
class _TestRepo extends TransactionsRepository {
  _TestRepo(super.client, this._userId);
  final String _userId;
  @override
  String get userId => _userId;
}

TransactionModel _tx({
  required String id,
  String userId = 'user-1',
  double amount = 10,
  TransactionType type = TransactionType.expense,
  String category = 'Comida',
  String? subcategory,
  String? description,
  DateTime? date,
  String currency = 'EUR',
  String? recurringTransactionId,
}) =>
    TransactionModel(
      id: id,
      userId: userId,
      amount: amount,
      type: type,
      category: category,
      subcategory: subcategory,
      description: description,
      date: date ?? DateTime.utc(2026, 3, 15),
      createdAt: DateTime.utc(2026, 3, 15),
      recurringTransactionId: recurringTransactionId,
      currency: currency,
    );

Map<String, dynamic> _row({
  required String id,
  String userId = 'user-1',
  double amount = 10,
  String type = 'expense',
  String category = 'Comida',
  String date = '2026-03-15',
  String createdAt = '2026-03-15T00:00:00Z',
  String currency = 'EUR',
}) =>
    {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date,
      'created_at': createdAt,
      'currency': currency,
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

  // ── getTransactions ──────────────────────────────────────────────────────

  group('getTransactions', () {
    test('returns rows scoped to the user_id filter', () async {
      await supabase.from('transactions').insert([
        _row(id: 't1', userId: 'user-1'),
        _row(id: 't2', userId: 'user-1', amount: 50, type: 'income', category: 'Salario'),
        _row(id: 't-other', userId: 'user-2', amount: 99, category: 'X'),
      ]);

      final result = await repo.getTransactions(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      final ids = result.map((t) => t.id).toList()..sort();
      expect(ids, ['t1', 't2']);
    });

    test('returns empty list when no matching rows', () async {
      final result = await repo.getTransactions(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(result, isEmpty);
    });

    test('maps row fields into TransactionModel correctly', () async {
      await supabase.from('transactions').insert(_row(
            id: 'tx-1',
            amount: 42.5,
            type: 'expense',
            category: 'Comida',
            date: '2026-03-20',
            createdAt: '2026-03-20T10:30:00Z',
            currency: 'USD',
          ));

      final result = await repo.getTransactions(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      expect(result, hasLength(1));
      final tx = result.single;
      expect(tx.id, 'tx-1');
      expect(tx.amount, 42.5);
      expect(tx.type, TransactionType.expense);
      expect(tx.category, 'Comida');
      expect(tx.currency, 'USD');
    });

    test('defaults currency to EUR when column is null', () async {
      await supabase.from('transactions').insert({
        'id': 'tx-1',
        'user_id': 'user-1',
        'amount': 10,
        'type': 'expense',
        'category': 'Comida',
        'date': '2026-03-15',
        'created_at': '2026-03-15T00:00:00Z',
        'currency': null,
      });

      final result = await repo.getTransactions(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      expect(result.single.currency, 'EUR');
    });
  });

  // ── deleteTransaction ────────────────────────────────────────────────────

  group('deleteTransaction', () {
    test('removes the row scoped to the user', () async {
      await supabase.from('transactions').insert([
        _row(id: 'tx-1', userId: 'user-1'),
        _row(id: 'tx-2', userId: 'user-2'),
      ]);

      await repo.deleteTransaction('tx-1');

      final left = await supabase.from('transactions').select();
      expect(left.map((r) => r['id']).toList(), ['tx-2']);
    });

    test('is a no-op when the id does not belong to the user', () async {
      await supabase.from('transactions').insert(_row(id: 'tx-other', userId: 'user-2'));

      await repo.deleteTransaction('tx-other');

      final left = await supabase.from('transactions').select();
      expect(left, hasLength(1));
    });
  });

  // ── upsertTransaction ────────────────────────────────────────────────────

  group('upsertTransaction', () {
    test('inserts a new row when id does not exist', () async {
      await repo.upsertTransaction(_tx(id: 'tx-new', amount: 7));

      final rows = await supabase.from('transactions').select();
      expect(rows, hasLength(1));
      expect(rows.first['id'], 'tx-new');
      expect(rows.first['amount'], 7);
    });
  });

  // ── getSummary ───────────────────────────────────────────────────────────

  group('getSummary', () {
    test('sums income and expense for matching rows', () async {
      await supabase.from('transactions').insert([
        _row(id: 'i1', type: 'income', amount: 200, category: 'Salario'),
        _row(id: 'e1', type: 'expense', amount: 30, category: 'X'),
        _row(id: 'e2', type: 'expense', amount: 70, category: 'Y'),
      ]);

      final summary = await repo.getSummary(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      expect(summary.income, 200);
      expect(summary.expense, 100);
      expect(summary.balance, 100);
    });

    test('returns zero summary when there are no transactions', () async {
      final summary = await repo.getSummary(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(summary.income, 0);
      expect(summary.expense, 0);
      expect(summary.balance, 0);
    });
  });

  // ── Error mapping ────────────────────────────────────────────────────────

  group('error mapping', () {
    test('AuthFailure from userId getter is re-thrown unchanged', () async {
      final realRepo = TransactionsRepository(supabase);
      await expectLater(
        () => realRepo.getTransactions(
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 12, 31),
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            'User not authenticated',
          ),
        ),
      );
    });

    test('PostgrestException is mapped to NetworkFailure', () async {
      // Re-build supabase with a trigger that throws on getTransactions
      mockHttp.close();
      mockHttp = MockSupabaseHttpClient(
        postgrestExceptionTrigger: (schema, table, body, type) {
          if (table == 'transactions' && type == RequestType.select) {
            throw PostgrestException(message: 'boom', code: '500');
          }
        },
      );
      supabase = SupabaseClient(
        'https://mock.supabase.co',
        'fakeAnonKey',
        httpClient: mockHttp,
      );
      repo = _TestRepo(supabase, 'user-1');

      await expectLater(
        () => repo.getTransactions(
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 12, 31),
        ),
        throwsA(
          isA<NetworkFailure>().having((f) => f.message, 'message', 'boom'),
        ),
      );
    });
  });

  // ── create/update (write paths) ──────────────────────────────────────────
  //
  // `createTransaction` and `updateTransaction` use `.insert(data).select()
  // .single()` and expect Postgres to fill in `created_at` automatically.
  // The mock HTTP client does not synthesise that column, so the response
  // round-trip fails inside `_fromRow`. We verify here that the failure
  // path still produces a typed `AppFailure`, and rely on integration
  // tests against a real database to exercise the happy path.

  group('createTransaction (failure path)', () {
    test('maps a missing created_at response into NetworkFailure', () async {
      // The mock echoes the inserted row, which has no created_at →
      // _fromRow throws → mapped to NetworkFailure.
      await expectLater(
        () => repo.createTransaction(_tx(id: 'new', amount: 12)),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
