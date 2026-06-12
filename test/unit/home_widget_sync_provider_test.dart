import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/services/home_widget_gateway.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/home_widget_sync_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

import '../helpers/mocks.dart';
import '../helpers/provider_container_helper.dart';

class _FakeAllTransactions extends AllTransactionsNotifier {
  @override
  Future<List<TransactionModel>> build() async => const [];
}

final _fakeUser = UserModel(
  id: 'u1',
  email: 'u1@test.com',
  createdAt: DateTime(2024, 1, 1),
);

TransactionModel _tx({
  required String id,
  double amount = 10,
  TransactionType type = TransactionType.expense,
}) =>
    TransactionModel(
      id: id,
      userId: 'u1',
      amount: amount,
      type: type,
      category: 'Comida',
      date: DateTime(2026, 6, 10),
      createdAt: DateTime(2026, 6, 10),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCommonFallbacks);

  late MockHomeWidgetGateway gateway;
  late MockTransactionsRepository txRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gateway = MockHomeWidgetGateway();
    txRepo = MockTransactionsRepository();
    when(() => gateway.saveWidgetData(any(), any())).thenAnswer((_) async {});
    when(() => gateway.updateWidget()).thenAnswer((_) async {});
  });

  ProviderContainer makeSyncContainer({bool loggedIn = true}) => makeContainer([
        homeWidgetGatewayProvider.overrideWithValue(gateway),
        currentUserProvider.overrideWith((ref) => loggedIn ? _fakeUser : null),
        allTransactionsProvider.overrideWith(_FakeAllTransactions.new),
        transactionsRepositoryProvider.overrideWith((ref) => txRepo),
      ]);

  test('publishes formatted month spent and balance, then repaints', () async {
    when(() => txRepo.getTransactions(
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => [
          _tx(id: 't1', amount: 1000, type: TransactionType.income),
          _tx(id: 't2', amount: 200.5),
          _tx(id: 't3', amount: 50),
        ]);

    final container = makeSyncContainer();
    await container.read(homeWidgetDataSyncProvider.future);

    // Default: EUR + dotDecimal (prefs vacías).
    verify(() => gateway.saveWidgetData(kWidgetMonthSpentKey, '€250.50'))
        .called(1);
    verify(() => gateway.saveWidgetData(kWidgetBalanceKey, '€749.50'))
        .called(1);
    verify(() => gateway.updateWidget()).called(1);
  });

  test('negative balance keeps the minus sign before the symbol', () async {
    when(() => txRepo.getTransactions(
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => [
          _tx(id: 't1', amount: 100, type: TransactionType.income),
          _tx(id: 't2', amount: 300),
        ]);

    final container = makeSyncContainer();
    await container.read(homeWidgetDataSyncProvider.future);

    verify(() => gateway.saveWidgetData(kWidgetBalanceKey, '-€200.00'))
        .called(1);
  });

  test('clears the widget data on logout', () async {
    final container = makeSyncContainer(loggedIn: false);
    await container.read(homeWidgetDataSyncProvider.future);

    verify(() => gateway.saveWidgetData(kWidgetMonthSpentKey, null)).called(1);
    verify(() => gateway.saveWidgetData(kWidgetBalanceKey, null)).called(1);
    verify(() => gateway.updateWidget()).called(1);
    verifyNever(() => txRepo.getTransactions(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ));
  });

  test('never throws when the gateway fails', () async {
    when(() => gateway.saveWidgetData(any(), any()))
        .thenThrow(Exception('platform channel down'));
    when(() => txRepo.getTransactions(
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => [_tx(id: 't1')]);

    final container = makeSyncContainer();
    await container.read(homeWidgetDataSyncProvider.future);
    // Sin excepción: el fallo queda registrado y la app sigue.
  });
}
