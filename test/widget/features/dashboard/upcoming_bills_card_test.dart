import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/core/providers/number_format_provider.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/features/dashboard/widgets/upcoming_bills_card.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/recurring_transactions_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

RecurringTransactionModel _rec(String desc, double amount) =>
    RecurringTransactionModel(
      id: desc,
      userId: 'u1',
      amount: amount,
      type: TransactionType.expense,
      category: 'Ocio',
      description: desc,
      recurrenceType: RecurrenceType.monthly,
      nextOccurrence: DateTime(2026, 9, 20),
      createdAt: DateTime(2026, 1, 1),
    );

Widget _wrap(List<RecurringTransactionModel> upcoming) => ProviderScope(
      overrides: [
        upcomingRecurringProvider.overrideWith((_) async => upcoming),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: const Scaffold(
          body: UpcomingBillsCard(
            cSymbol: r'$',
            numFmtStyle: NumberFormatStyle.dotDecimal,
          ),
        ),
      ),
    );

void main() {
  testWidgets('suma los importes y nombra los recibos', (tester) async {
    await tester.pumpWidget(_wrap([_rec('Spotify', 9.99), _rec('Gym', 30.0)]));
    await tester.pumpAndSettle();

    expect(find.text('Próximos recibos'), findsOneWidget);
    expect(find.text(r'$39.99'), findsOneWidget);
    expect(find.text('Spotify · Gym'), findsOneWidget);
  });

  testWidgets('resume con +N cuando hay más de dos', (tester) async {
    await tester.pumpWidget(_wrap([
      _rec('Spotify', 10),
      _rec('Gym', 10),
      _rec('Netflix', 10),
      _rec('Luz', 10),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Spotify · Gym +2'), findsOneWidget);
  });

  testWidgets('sin nada programado no ocupa espacio', (tester) async {
    await tester.pumpWidget(_wrap([]));
    await tester.pumpAndSettle();

    expect(find.text('Próximos recibos'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });
}
