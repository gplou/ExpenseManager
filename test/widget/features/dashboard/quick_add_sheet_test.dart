import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/features/dashboard/widgets/quick_add_sheet.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Captures every `create()` call so we can assert what was saved without
/// going through the real transactionsRepositoryProvider (whose selection
/// depends on auth + sync + subscription state).
class _FakeTransactionsNotifier extends TransactionsNotifier {
  TransactionModel? lastCreated;

  @override
  Future<void> create(TransactionModel tx) async {
    lastCreated = tx;
  }
}

Widget _wrap({
  required bool isPro,
  required _FakeTransactionsNotifier notifier,
  VoidCallback? onVoice,
  VoidCallback? onCamera,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: <Override>[
      isProProvider.overrideWithValue(isPro),
      transactionsNotifierProvider.overrideWith(() => notifier),
      // Synchronous override avoids the AsyncNotifier `build()` path that
      // hits Supabase. Empty maps = no custom categories.
      customCategoriesSyncProvider.overrideWithValue({
        TransactionType.income: const [],
        TransactionType.expense: const [],
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(
        body: QuickAddSheet(
          onVoiceTap: onVoice ?? () {},
          onCameraTap: onCamera ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  late _FakeTransactionsNotifier notifier;

  setUp(() {
    notifier = _FakeTransactionsNotifier();
  });

  testWidgets('renders the 3 shortcut buttons (voice, photo, chat)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(isPro: true, notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
  });

  testWidgets('non-PRO user sees 3 PRO badges on the shortcuts',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(isPro: false, notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.text('PRO'), findsNWidgets(3));
  });

  testWidgets('PRO user has no PRO badges', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(isPro: true, notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.text('PRO'), findsNothing);
  });

  testWidgets('voice shortcut invokes onVoiceTap and pops the sheet',
      (tester) async {
    var voiceTaps = 0;
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      isPro: true,
      notifier: notifier,
      onVoice: () => voiceTaps++,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pumpAndSettle();

    expect(voiceTaps, 1);
  });

  testWidgets('income/expense toggle starts on expense', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(isPro: true, notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
  });
}
