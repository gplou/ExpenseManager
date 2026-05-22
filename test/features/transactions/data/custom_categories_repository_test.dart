import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_supabase_http_client/mock_supabase_http_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/features/transactions/data/custom_categories_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

class _TestRepo extends CustomCategoriesRepository {
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

  // ── getByType ────────────────────────────────────────────────────────────

  group('getByType', () {
    test('maps rows with material icon codePoints into TransactionCategory',
        () async {
      final iconCp = TransactionCategories.pickableIcons.first.codePoint;
      await supabase.from('custom_categories').insert([
        {
          'user_id': 'user-1',
          'name': 'Mi categoria',
          'type': 'expense',
          'icon_code': iconCp,
          'created_at': '2026-03-15T00:00:00Z',
        },
      ]);

      final result = await repo.getByType(TransactionType.expense);

      expect(result, hasLength(1));
      expect(result.single.name, 'Mi categoria');
      expect(result.single.icon.codePoint, iconCp);
      expect(result.single.emojiOverride, isNull);
    });

    test('maps non-pickable icon codePoint into emojiOverride', () async {
      // U+1F4B0 = 💰 (money bag) — not a Material icon
      const moneyBag = 0x1F4B0;
      await supabase.from('custom_categories').insert([
        {
          'user_id': 'user-1',
          'name': 'Inversiones',
          'type': 'income',
          'icon_code': moneyBag,
          'created_at': '2026-03-15T00:00:00Z',
        },
      ]);

      final result = await repo.getByType(TransactionType.income);

      expect(result, hasLength(1));
      expect(result.single.name, 'Inversiones');
      expect(result.single.icon, Icons.label_outlined);
      expect(result.single.emojiOverride, String.fromCharCode(moneyBag));
    });

    test('scopes results to the current userId and type', () async {
      final iconCp = TransactionCategories.pickableIcons.first.codePoint;
      await supabase.from('custom_categories').insert([
        {
          'user_id': 'user-1',
          'name': 'mine-expense',
          'type': 'expense',
          'icon_code': iconCp,
          'created_at': '2026-03-15T00:00:00Z',
        },
        {
          'user_id': 'user-1',
          'name': 'mine-income',
          'type': 'income',
          'icon_code': iconCp,
          'created_at': '2026-03-15T00:00:00Z',
        },
        {
          'user_id': 'user-2',
          'name': 'others',
          'type': 'expense',
          'icon_code': iconCp,
          'created_at': '2026-03-15T00:00:00Z',
        },
      ]);

      final result = await repo.getByType(TransactionType.expense);

      expect(result.map((c) => c.name), ['mine-expense']);
    });

    test('returns empty list when no rows match', () async {
      final result = await repo.getByType(TransactionType.expense);
      expect(result, isEmpty);
    });
  });

  // ── add ──────────────────────────────────────────────────────────────────

  group('add', () {
    test('inserts a row with the material icon codePoint', () async {
      final icon = TransactionCategories.pickableIcons.first;
      await repo.add(
        TransactionType.expense,
        TransactionCategory(name: 'Nueva', icon: icon),
      );

      final rows = await supabase.from('custom_categories').select();
      expect(rows, hasLength(1));
      expect(rows.first['name'], 'Nueva');
      expect(rows.first['type'], 'expense');
      expect(rows.first['icon_code'], icon.codePoint);
      expect(rows.first['user_id'], 'user-1');
    });

    test('stores the emoji rune when emojiOverride is provided', () async {
      const emoji = '💰';
      await repo.add(
        TransactionType.income,
        TransactionCategory(
          name: 'Crypto',
          icon: Icons.label_outlined,
          emojiOverride: emoji,
        ),
      );

      final rows = await supabase.from('custom_categories').select();
      expect(rows.single['icon_code'], emoji.runes.first);
    });
  });

  // ── remove ───────────────────────────────────────────────────────────────

  group('remove', () {
    test('deletes the row matching name + type for the user', () async {
      final iconCp = TransactionCategories.pickableIcons.first.codePoint;
      await supabase.from('custom_categories').insert([
        {
          'user_id': 'user-1',
          'name': 'to-remove',
          'type': 'expense',
          'icon_code': iconCp,
          'created_at': '2026-03-15T00:00:00Z',
        },
        {
          'user_id': 'user-1',
          'name': 'keep',
          'type': 'expense',
          'icon_code': iconCp,
          'created_at': '2026-03-15T00:00:00Z',
        },
      ]);

      await repo.remove(TransactionType.expense, 'to-remove');

      final left = await supabase.from('custom_categories').select();
      expect(left.map((r) => r['name']), ['keep']);
    });

    test('does not touch other users\' rows with the same name', () async {
      final iconCp = TransactionCategories.pickableIcons.first.codePoint;
      await supabase.from('custom_categories').insert([
        {
          'user_id': 'user-2',
          'name': 'shared-name',
          'type': 'expense',
          'icon_code': iconCp,
          'created_at': '2026-03-15T00:00:00Z',
        },
      ]);

      await repo.remove(TransactionType.expense, 'shared-name');

      final left = await supabase.from('custom_categories').select();
      expect(left, hasLength(1));
      expect(left.single['user_id'], 'user-2');
    });
  });
}
