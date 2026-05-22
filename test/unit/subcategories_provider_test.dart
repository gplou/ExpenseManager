import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/subcategories_provider.dart';

import '../helpers/mocks.dart';
import '../helpers/provider_container_helper.dart';

class _MockSubRepo extends Mock implements SubcategoriesRepository {}

void main() {
  setUpAll(() {
    registerCommonFallbacks();
    registerFallbackValue(TransactionType.expense);
  });

  test('forwards the call to repo.getForCategory with the family params',
      () async {
    final repo = _MockSubRepo();
    when(() => repo.getForCategory(any(), any()))
        .thenAnswer((_) async => ['Cena', 'Desayuno']);

    final container = makeContainer([
      subcategoriesRepositoryProvider.overrideWithValue(repo),
    ]);

    final result = await container.read(
      subcategoriesProvider(
        (category: 'Comida', type: TransactionType.expense),
      ).future,
    );

    expect(result, ['Cena', 'Desayuno']);
    verify(() => repo.getForCategory('Comida', TransactionType.expense))
        .called(1);
  });

  test('different family keys re-evaluate independently', () async {
    final repo = _MockSubRepo();
    when(() => repo.getForCategory('Comida', any()))
        .thenAnswer((_) async => ['a']);
    when(() => repo.getForCategory('Transporte', any()))
        .thenAnswer((_) async => ['b']);

    final container = makeContainer([
      subcategoriesRepositoryProvider.overrideWithValue(repo),
    ]);

    final a = await container.read(
      subcategoriesProvider(
        (category: 'Comida', type: TransactionType.expense),
      ).future,
    );
    final b = await container.read(
      subcategoriesProvider(
        (category: 'Transporte', type: TransactionType.expense),
      ).future,
    );

    expect(a, ['a']);
    expect(b, ['b']);
  });
}
