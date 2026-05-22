import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/create_subcategory_dialog.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../../../helpers/mocks.dart';

class _MockSubRepo extends Mock implements SubcategoriesRepository {}

Widget _wrap({required List<Override> overrides, required Widget home}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: home,
      ),
    );

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-btn')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerCommonFallbacks();
    registerFallbackValue(TransactionType.expense);
  });

  late _MockSubRepo repo;

  setUp(() {
    repo = _MockSubRepo();
  });

  Widget harness() {
    return _wrap(
      overrides: [
        subcategoriesRepositoryProvider.overrideWithValue(repo),
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const Key('open-btn'),
              onPressed: () {
                showDialog<String>(
                  context: context,
                  builder: (_) => const CreateSubcategoryDialog(
                    category: 'Comida',
                    type: TransactionType.expense,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders title and a disabled Save button initially',
      (tester) async {
    await tester.pumpWidget(harness());
    await _openDialog(tester);

    expect(find.text('Nueva subcategoría'), findsOneWidget);
    final saveButton = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'));
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('Save is enabled once the name is non-empty', (tester) async {
    await tester.pumpWidget(harness());
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField), 'Cena');
    await tester.pumpAndSettle();

    final saveButton = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'));
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('Save calls the repository with trimmed name and pops with value',
      (tester) async {
    when(() => repo.add(any(), any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField), '  Cena  ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    verify(() => repo.add('Comida', TransactionType.expense, 'Cena')).called(1);
    // Dialog dismissed
    expect(find.text('Nueva subcategoría'), findsNothing);
  });

  testWidgets('Cancel dismisses without calling the repo', (tester) async {
    await tester.pumpWidget(harness());
    await _openDialog(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.add(any(), any(), any()));
    expect(find.text('Nueva subcategoría'), findsNothing);
  });
}
