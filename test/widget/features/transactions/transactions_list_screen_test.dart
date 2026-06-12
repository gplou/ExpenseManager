import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Fake notifier so we can seed the screen with deterministic data
/// without touching the real Supabase / SQLite stack.
class _FakeAllTransactions extends AllTransactionsNotifier {
  _FakeAllTransactions(this._items);
  final List<TransactionModel> _items;

  @override
  Future<List<TransactionModel>> build() async => _items;
}

TransactionModel _tx({
  required String id,
  TransactionType type = TransactionType.expense,
  String category = 'Comida',
  double amount = 25,
  String? subcategory,
  DateTime? date,
}) =>
    TransactionModel(
      id: id,
      userId: 'u',
      amount: amount,
      type: type,
      category: category,
      subcategory: subcategory,
      date: date ?? DateTime(2026, 3, 15),
      createdAt: DateTime(2026, 3, 15),
    );

Widget _wrap(List<TransactionModel> items) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      // Hide the ad banner — it would try to load real ads.
      isProProvider.overrideWithValue(true),
      allTransactionsProvider.overrideWith(() => _FakeAllTransactions(items)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: const TransactionsListScreen(),
    ),
  );
}

void main() {
  testWidgets('shows the empty state when there are no transactions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    // Spanish: "Sin transacciones"
    expect(find.textContaining('Sin transacciones'), findsAtLeastNWidgets(1));
  });

  testWidgets('renders one row per transaction', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([
      _tx(id: 't1', category: 'Comida', amount: 10),
      _tx(id: 't2', category: 'Transporte', amount: 20),
      _tx(id: 't3', category: 'Ocio', amount: 30),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    expect(find.text('Ocio'), findsOneWidget);
  });

  testWidgets('long-press on a row enters selection mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([
      _tx(id: 't1', category: 'Comida'),
      _tx(id: 't2', category: 'Transporte'),
    ]));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Comida'));
    await tester.pumpAndSettle();

    // Selection-mode AppBar shows a count of 1.
    expect(find.textContaining('1'), findsAtLeastNWidgets(1));
  });

  group('search mode', () {
    Future<void> enterSearch(WidgetTester tester, String query) async {
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), query);
      // Debounce de 300ms antes de aplicar la query.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    testWidgets('filters rows by category as the user types', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap([
        _tx(id: 't1', category: 'Comida'),
        _tx(id: 't2', category: 'Transporte'),
        _tx(id: 't3', category: 'Ocio'),
      ]));
      await tester.pumpAndSettle();

      await enterSearch(tester, 'transporte');

      expect(find.text('Transporte'), findsOneWidget);
      expect(find.text('Comida'), findsNothing);
      expect(find.text('Ocio'), findsNothing);
    });

    testWidgets('shows the search empty state when nothing matches',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap([
        _tx(id: 't1', category: 'Comida'),
      ]));
      await tester.pumpAndSettle();

      await enterSearch(tester, 'zzz');

      expect(find.text('Sin resultados para tu búsqueda'), findsOneWidget);
    });

    testWidgets('closing search restores the full list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap([
        _tx(id: 't1', category: 'Comida'),
        _tx(id: 't2', category: 'Transporte'),
      ]));
      await tester.pumpAndSettle();

      await enterSearch(tester, 'zzz');
      expect(find.text('Comida'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Comida'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
    });
  });
}
