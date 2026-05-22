import 'package:flutter_test/flutter_test.dart';
import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

class _TestRepo extends SubcategoriesRepository {
  _TestRepo(super.client, this._userId);
  final String _userId;
  @override
  String get userId => _userId;
}

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

  // ── getForCategory ───────────────────────────────────────────────────────

  group('getForCategory', () {
    test('returns names scoped to user + category + type', () async {
      await supabase.from('subcategories').insert([
        {
          'user_id': 'user-1',
          'category': 'Comida',
          'type': 'expense',
          'name': 'Cena',
          'created_at': '2026-03-15T00:00:00Z',
        },
        {
          'user_id': 'user-1',
          'category': 'Comida',
          'type': 'expense',
          'name': 'Desayuno',
          'created_at': '2026-03-16T00:00:00Z',
        },
        {
          'user_id': 'user-1',
          'category': 'Transporte', // different category
          'type': 'expense',
          'name': 'Taxi',
          'created_at': '2026-03-15T00:00:00Z',
        },
        {
          'user_id': 'user-2', // different user
          'category': 'Comida',
          'type': 'expense',
          'name': 'Brunch',
          'created_at': '2026-03-15T00:00:00Z',
        },
      ]);

      final result = await repo.getForCategory('Comida', TransactionType.expense);

      expect(result..sort(), ['Cena', 'Desayuno']);
    });

    test('returns empty list when no rows match', () async {
      final result = await repo.getForCategory('Otros', TransactionType.income);
      expect(result, isEmpty);
    });
  });

  // ── add ──────────────────────────────────────────────────────────────────

  group('add', () {
    test('inserts row with user_id, category, type, name', () async {
      await repo.add('Comida', TransactionType.expense, 'Brunch');

      final rows = await supabase.from('subcategories').select();
      expect(rows, hasLength(1));
      expect(rows.single['user_id'], 'user-1');
      expect(rows.single['category'], 'Comida');
      expect(rows.single['type'], 'expense');
      expect(rows.single['name'], 'Brunch');
    });
  });

  // ── remove ───────────────────────────────────────────────────────────────

  group('remove', () {
    test('deletes only the matching row', () async {
      await supabase.from('subcategories').insert([
        {
          'user_id': 'user-1',
          'category': 'Comida',
          'type': 'expense',
          'name': 'Cena',
          'created_at': '2026-03-15T00:00:00Z',
        },
        {
          'user_id': 'user-1',
          'category': 'Comida',
          'type': 'expense',
          'name': 'Desayuno',
          'created_at': '2026-03-15T00:00:00Z',
        },
      ]);

      await repo.remove('Comida', TransactionType.expense, 'Cena');

      final left = await supabase.from('subcategories').select();
      expect(left.map((r) => r['name']), ['Desayuno']);
    });

    test('does not delete rows belonging to other users', () async {
      await supabase.from('subcategories').insert({
        'user_id': 'user-2',
        'category': 'Comida',
        'type': 'expense',
        'name': 'Shared',
        'created_at': '2026-03-15T00:00:00Z',
      });

      await repo.remove('Comida', TransactionType.expense, 'Shared');

      final left = await supabase.from('subcategories').select();
      expect(left, hasLength(1));
    });
  });
}
