import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/transactions/data/custom_categories_repository.dart';
import 'package:expense_manager/features/transactions/domain/custom_categories_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/create_category_dialog.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../../../helpers/mocks.dart';

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
    registerFallbackValue(
        const TransactionCategory(name: '_', icon: Icons.label_outlined));
  });

  late MockCustomCategoriesRepository repo;

  setUp(() {
    repo = MockCustomCategoriesRepository();
    when(() => repo.getByType(any())).thenAnswer((_) async => const []);
    when(() => repo.add(any(), any())).thenAnswer((_) async {});
  });

  Widget harness() => _wrap(
        overrides: [
          customCategoriesRepositoryProvider.overrideWith(
            (ref) => repo as CustomCategoriesRepositoryContract,
          ),
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const Key('open-btn'),
                onPressed: () {
                  showDialog<String>(
                    context: context,
                    builder: (_) => const CreateCategoryDialog(
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

  testWidgets('Save is disabled until the name field has text', (tester) async {
    await tester.pumpWidget(harness());
    await _openDialog(tester);

    final save = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'));
    expect(save.onPressed, isNull);
  });

  testWidgets(
      'first emoji character is captured even when many are typed at once',
      (tester) async {
    await tester.pumpWidget(harness());
    await _openDialog(tester);

    // Emoji input is the first TextField (width 100). Use byType(EditableText)
    // and target the first one.
    final emojiField = find.byType(TextField).first;
    await tester.enterText(emojiField, '💎🚀');
    await tester.pumpAndSettle();

    // The field should only contain the first emoji
    final editable = tester.firstWidget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '💎');
  });

  testWidgets(
      'Save calls repo.add with name + custom emoji when both are provided',
      (tester) async {
    await tester.pumpWidget(harness());
    await _openDialog(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '💎');
    await tester.enterText(fields.last, 'Crypto');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.add(TransactionType.expense, captureAny()))
        .captured
        .single as TransactionCategory;
    expect(captured.name, 'Crypto');
    expect(captured.emojiOverride, '💎');
  });

  testWidgets('Save uses the 💸 default emoji when none is entered',
      (tester) async {
    await tester.pumpWidget(harness());
    await _openDialog(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.last, 'Default');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.add(TransactionType.expense, captureAny()))
        .captured
        .single as TransactionCategory;
    expect(captured.emojiOverride, '💸');
  });

  testWidgets('Cancel dismisses without calling the repo', (tester) async {
    await tester.pumpWidget(harness());
    await _openDialog(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.add(any(), any()));
    expect(find.text('Nueva categoría'), findsNothing);
  });
}
