import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/services/notification_service.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/recurring_reminders_provider.dart';

import '../helpers/clock_helper.dart';
import '../helpers/mocks.dart';
import '../helpers/provider_container_helper.dart';

final _fakeUser = UserModel(
  id: 'u1',
  email: 'u1@test.com',
  createdAt: DateTime(2024, 1, 1),
);

RecurringTransactionModel _recurring({
  String id = 'r1',
  String? description = 'Netflix',
  DateTime? nextOccurrence,
}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'u1',
      amount: 9.99,
      type: TransactionType.expense,
      category: 'Ocio',
      description: description,
      recurrenceType: RecurrenceType.monthly,
      nextOccurrence: nextOccurrence ?? DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerCommonFallbacks);

  late MockNotificationService service;
  late MockRecurringTransactionsRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MockNotificationService();
    repo = MockRecurringTransactionsRepository();
    when(() => service.cancelAll()).thenAnswer((_) async {});
    when(() => service.schedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          when: any(named: 'when'),
          channelName: any(named: 'channelName'),
          channelDescription: any(named: 'channelDescription'),
        )).thenAnswer((_) async {});
  });

  makeRemindersContainer() => makeContainer([
        currentUserProvider.overrideWith((ref) => _fakeUser),
        notificationServiceProvider.overrideWithValue(service),
        recurringTransactionsRepositoryProvider.overrideWith((ref) => repo),
      ]);

  test('defaults to disabled and resync is a no-op', () async {
    final container = makeRemindersContainer();
    expect(await container.read(recurringRemindersProvider.future), isFalse);

    await container.read(recurringRemindersProvider.notifier).resync();

    verifyNever(() => service.cancelAll());
    verifyNever(() => repo.getAllForUser());
  });

  test('enable() requests permission, persists and schedules day-before 9:00',
      () async {
    when(() => service.requestPermissions()).thenAnswer((_) async => true);
    when(() => repo.getAllForUser()).thenAnswer((_) async => [
          _recurring(nextOccurrence: DateTime(2026, 7, 1)),
        ]);

    final container = makeRemindersContainer();
    // Espera el build inicial (como hace la UI al watchear el switch) para
    // que no sobreescriba el estado que setea enable().
    await container.read(recurringRemindersProvider.future);
    final granted = await withFixedClock(
      DateTime(2026, 6, 12),
      () => container.read(recurringRemindersProvider.notifier).enable(),
    );

    expect(granted, isTrue);
    expect(container.read(recurringRemindersProvider).value, isTrue);

    final captured = verify(() => service.schedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: captureAny(named: 'body'),
          when: captureAny(named: 'when'),
          channelName: any(named: 'channelName'),
          channelDescription: any(named: 'channelDescription'),
        )).captured;
    expect(captured[0], contains('Netflix'));
    expect(captured[1], DateTime(2026, 6, 30, kReminderHour));

    // Persistencia: un contenedor nuevo arranca con el toggle activado.
    final fresh = makeRemindersContainer();
    expect(await fresh.read(recurringRemindersProvider.future), isTrue);
  });

  test('enable() returns false and stays off when permission is denied',
      () async {
    when(() => service.requestPermissions()).thenAnswer((_) async => false);

    final container = makeRemindersContainer();
    await container.read(recurringRemindersProvider.future);
    final granted =
        await container.read(recurringRemindersProvider.notifier).enable();

    expect(granted, isFalse);
    expect(await container.read(recurringRemindersProvider.future), isFalse);
    verifyNever(() => repo.getAllForUser());
  });

  test('disable() persists and cancels everything', () async {
    SharedPreferences.setMockInitialValues(
        {'recurring_reminders_enabled': true});

    final container = makeRemindersContainer();
    await container.read(recurringRemindersProvider.future);
    await container.read(recurringRemindersProvider.notifier).disable();

    expect(container.read(recurringRemindersProvider).value, isFalse);
    verify(() => service.cancelAll()).called(1);
  });

  test('resync uses the localized category when there is no description',
      () async {
    SharedPreferences.setMockInitialValues(
        {'recurring_reminders_enabled': true});
    when(() => repo.getAllForUser()).thenAnswer((_) async => [
          _recurring(description: null, nextOccurrence: DateTime(2026, 8, 15)),
        ]);

    final container = makeRemindersContainer();
    await withFixedClock(
      DateTime(2026, 6, 12),
      () => container.read(recurringRemindersProvider.notifier).resync(),
    );

    final body = verify(() => service.schedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: captureAny(named: 'body'),
          when: any(named: 'when'),
          channelName: any(named: 'channelName'),
          channelDescription: any(named: 'channelDescription'),
        )).captured.single as String;
    // Locale por defecto 'es': la clave de BD 'Ocio' se muestra tal cual.
    expect(body, contains('Ocio'));
  });

  test('resync never throws when the repository fails', () async {
    SharedPreferences.setMockInitialValues(
        {'recurring_reminders_enabled': true});
    when(() => repo.getAllForUser()).thenThrow(Exception('db down'));

    final container = makeRemindersContainer();
    await container.read(recurringRemindersProvider.notifier).resync();
    // Sin excepción: el CRUD que lo dispara no se ve afectado.
  });
}
