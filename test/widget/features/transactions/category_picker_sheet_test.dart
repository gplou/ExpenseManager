import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/category_picker_sheet.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

Widget _wrap({String? Function(String?)? capture}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      // Inject a synchronous custom-categories list so the consumer reads it
      // without awaiting the AsyncNotifier build path (which would touch
      // SharedPreferences and Supabase).
      customCategoriesSyncProvider.overrideWithValue({
        TransactionType.expense: const [
          TransactionCategory(
            name: 'Cripto',
            icon: Icons.label_outlined,
            emojiOverride: '💎',
          ),
        ],
        TransactionType.income: const [],
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(
        body: Builder(
          builder: (context) => Consumer(
            builder: (context, ref, _) => FilledButton(
              key: const Key('open-btn'),
              onPressed: () async {
                final selected = await showCategoryPickerSheet(
                  context,
                  ref,
                  type: TransactionType.expense,
                  selectedCategory: null,
                  accentColor: Colors.red,
                  accentLight: Colors.red.shade100,
                );
                capture?.call(selected);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Default test viewport (800x600) is shorter than the picker grid.
/// Enlarges the surface so the sheet fits without RenderFlex overflow.
Future<void> _enlargeViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('renders built-in expense categories + custom category',
      (tester) async {
    await _enlargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.tap(find.byKey(const Key('open-btn')));
    await tester.pumpAndSettle();

    // Header
    expect(find.text('CATEGORÍA'), findsOneWidget);

    // Built-in expense names are localised. "Comida" should be present.
    expect(find.text('Comida'), findsOneWidget);
    // Custom category from the override
    expect(find.text('Cripto'), findsOneWidget);
    expect(find.text('💎'), findsOneWidget);
  });

  testWidgets('tapping a category pops the sheet with its name',
      (tester) async {
    await _enlargeViewport(tester);
    String? selected;
    await tester.pumpWidget(_wrap(capture: (s) => selected = s));
    await tester.tap(find.byKey(const Key('open-btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comida'));
    await tester.pumpAndSettle();

    expect(selected, 'Comida');
    // Sheet dismissed
    expect(find.text('CATEGORÍA'), findsNothing);
  });
}
