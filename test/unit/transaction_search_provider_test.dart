import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/locale_provider.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transaction_search_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../helpers/provider_container_helper.dart';

class _FakeAllTransactions extends AllTransactionsNotifier {
  _FakeAllTransactions(this._items);
  final List<TransactionModel> _items;

  @override
  Future<List<TransactionModel>> build() async => _items;
}

class _FakeLocale extends LocaleNotifier {
  _FakeLocale(this._locale);
  final Locale _locale;

  @override
  Future<Locale> build() async => _locale;
}

TransactionModel _tx({
  required String id,
  String category = 'Comida',
  String? subcategory,
  String? description,
  double amount = 25,
}) =>
    TransactionModel(
      id: id,
      userId: 'u',
      amount: amount,
      type: TransactionType.expense,
      category: category,
      subcategory: subcategory,
      description: description,
      date: DateTime(2026, 3, 15),
      createdAt: DateTime(2026, 3, 15),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10nEs = lookupAppLocalizations(const Locale('es'));
  final l10nEn = lookupAppLocalizations(const Locale('en'));

  group('filterTransactionsByQuery', () {
    test('empty query returns the original list untouched', () {
      final items = [_tx(id: 't1'), _tx(id: 't2')];
      expect(filterTransactionsByQuery(items, '', l10nEs), items);
      expect(filterTransactionsByQuery(items, '   ', l10nEs), items);
    });

    test('matches description case-insensitive', () {
      final items = [
        _tx(id: 't1', description: 'Cena con Ana'),
        _tx(id: 't2', description: 'Gasolina'),
      ];
      final result = filterTransactionsByQuery(items, 'CENA', l10nEs);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('matches description accent-insensitive ("cafe" finds "Café")', () {
      final items = [
        _tx(id: 't1', description: 'Café del barrio'),
        _tx(id: 't2', description: 'Supermercado'),
      ];
      expect(
        filterTransactionsByQuery(items, 'cafe', l10nEs).map((t) => t.id),
        ['t1'],
      );
      // Y al revés: query con acento encuentra texto sin acento.
      expect(
        filterTransactionsByQuery(
          [_tx(id: 't3', description: 'cafeteria')],
          'cafetería',
          l10nEs,
        ).map((t) => t.id),
        ['t3'],
      );
    });

    test('matches the localized category name in the active locale', () {
      final items = [
        _tx(id: 't1', category: 'Comida'),
        _tx(id: 't2', category: 'Transporte'),
      ];
      // En inglés, la clave de BD 'Comida' se muestra como "Food".
      final result = filterTransactionsByQuery(items, 'food', l10nEn);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('matches the raw DB category key regardless of locale', () {
      final items = [_tx(id: 't1', category: 'Comida')];
      // Con l10n en inglés, "comida" sigue funcionando vía la clave de BD.
      final result = filterTransactionsByQuery(items, 'comida', l10nEn);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('matches custom categories by their own name', () {
      final items = [_tx(id: 't1', category: 'Mascotas')];
      expect(
        filterTransactionsByQuery(items, 'masco', l10nEs).map((t) => t.id),
        ['t1'],
      );
    });

    test('matches subcategory', () {
      final items = [
        _tx(id: 't1', subcategory: 'Restaurante'),
        _tx(id: 't2', subcategory: 'Súper'),
      ];
      expect(
        filterTransactionsByQuery(items, 'restau', l10nEs).map((t) => t.id),
        ['t1'],
      );
    });

    test('matches amount with dot or comma decimals', () {
      final items = [
        _tx(id: 't1', amount: 12.5),
        _tx(id: 't2', amount: 80),
      ];
      expect(
        filterTransactionsByQuery(items, '12.5', l10nEs).map((t) => t.id),
        ['t1'],
      );
      expect(
        filterTransactionsByQuery(items, '12,50', l10nEs).map((t) => t.id),
        ['t1'],
      );
      expect(
        filterTransactionsByQuery(items, '80', l10nEs).map((t) => t.id),
        ['t2'],
      );
    });

    test('returns empty list when nothing matches', () {
      final items = [_tx(id: 't1', description: 'Cena')];
      expect(filterTransactionsByQuery(items, 'zzz', l10nEs), isEmpty);
    });
  });

  group('filteredTransactionsProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    List<TransactionModel> items() => [
          _tx(id: 't1', category: 'Comida', description: 'Cena'),
          _tx(id: 't2', category: 'Transporte', description: 'Taxi'),
          _tx(id: 't3', category: 'Ocio', amount: 42),
        ];

    test('returns the full list while the query is empty', () async {
      final container = makeContainer([
        allTransactionsProvider.overrideWith(() => _FakeAllTransactions(items())),
        localeProvider.overrideWith(() => _FakeLocale(const Locale('es'))),
      ]);
      final sub = container.listen(filteredTransactionsProvider, (_, __) {});
      addTearDown(sub.close);

      final result = await container.read(filteredTransactionsProvider.future);
      expect(result.length, 3);
    });

    test('reacts to query changes and filters the list', () async {
      final container = makeContainer([
        allTransactionsProvider.overrideWith(() => _FakeAllTransactions(items())),
        localeProvider.overrideWith(() => _FakeLocale(const Locale('es'))),
      ]);
      final sub = container.listen(filteredTransactionsProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(filteredTransactionsProvider.future);

      container.read(transactionSearchQueryProvider.notifier).set('taxi');
      final filtered =
          await container.read(filteredTransactionsProvider.future);
      expect(filtered.map((t) => t.id), ['t2']);

      container.read(transactionSearchQueryProvider.notifier).clear();
      final restored =
          await container.read(filteredTransactionsProvider.future);
      expect(restored.length, 3);
    });
  });
}
