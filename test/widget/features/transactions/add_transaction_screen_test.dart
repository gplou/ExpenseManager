import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_manager/core/providers/currency_provider.dart';
import 'package:expense_manager/core/services/image_input_gateway.dart';
import 'package:expense_manager/core/services/voice_input_gateway.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/subcategories_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/presentation/providers/custom_categories_provider.dart';
import 'package:expense_manager/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/recent_categories_strip.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockTransactionsRepo extends Mock
    implements TransactionsRepositoryContract {}

class _MockRecurringRepo extends Mock
    implements RecurringTransactionsRepositoryContract {}

class _MockSubRepo extends Mock implements SubcategoriesRepository {}

class _FakeVoiceGateway extends Fake implements VoiceInputGateway {
  @override
  String get mimeType => 'audio/wav';

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
}

class _FakeImageGateway extends Fake implements ImageInputGateway {}

class _FakeVoiceParser extends Fake implements VoiceTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(
    Uint8List audioBytes, {
    String mimeType = 'audio/wav',
    List<Map<String, String>> subcategories = const [],
  }) async =>
      null;
}

class _FakeImageParser extends Fake implements ImageTransactionParser {
  @override
  Future<ParsedVoiceTransaction?> parse(String imagePath) async => null;
}

/// Immediately "records" a well-formed fake audio file — drives the
/// in-screen mic button end-to-end without a real microphone. Pair with a
/// parser fake (e.g. [_VoiceParserReturning]) to control what comes back.
class _AutoVoiceGateway extends Fake implements VoiceInputGateway {
  String? _path;

  @override
  String get mimeType => 'audio/wav';

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {
    final file = File(
      '${Directory.systemTemp.path}/voice_test_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(List.filled(8000, 1));
    _path = file.path;
  }

  @override
  Future<String?> stop() async => _path;

  @override
  Future<void> cancel() async {}

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
}

/// hasPermission() succeeds, but start() throws — the recording backend can
/// fail to acquire the mic (hardware busy, permission revoked mid-session,
/// etc.) even after the initial permission check passed.
class _StartThrowsVoiceGateway extends Fake implements VoiceInputGateway {
  @override
  String get mimeType => 'audio/wav';

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {
    throw PlatformException(
      code: 'recorderNotAvailable',
      message: 'Recording not available on this device',
    );
  }

  @override
  Future<void> cancel() async {}
}

/// Records successfully, but stop() resolves to a file with only a handful
/// of bytes — e.g. an accidental instant tap. The screen should treat this
/// like "nothing understood", not silently reset.
class _TooShortRecordingVoiceGateway extends Fake implements VoiceInputGateway {
  @override
  String get mimeType => 'audio/wav';

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<String?> stop() async {
    final file = File(
      '${Directory.systemTemp.path}/voice_test_short_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(const [1, 2, 3]);
    return file.path;
  }

  @override
  Future<void> cancel() async {}

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
}

/// Immediately "picks" a fake file — drives the in-screen camera button
/// end-to-end without a real picker/camera.
class _AutoImageGateway extends Fake implements ImageInputGateway {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async =>
      XFile('/tmp/fake_receipt.jpg');
}

class _VoiceParserReturning extends Fake implements VoiceTransactionParser {
  _VoiceParserReturning(this.result);
  final ParsedVoiceTransaction? result;

  @override
  Future<ParsedVoiceTransaction?> parse(
    Uint8List audioBytes, {
    String mimeType = 'audio/wav',
    List<Map<String, String>> subcategories = const [],
  }) async =>
      result;
}

/// Returns a different queued result on each successive `parse()` call —
/// simulates re-tapping the mic to redo a capture.
class _QueuedVoiceParser extends Fake implements VoiceTransactionParser {
  _QueuedVoiceParser(this._results);
  final List<ParsedVoiceTransaction?> _results;
  int _index = 0;

  @override
  Future<ParsedVoiceTransaction?> parse(
    Uint8List audioBytes, {
    String mimeType = 'audio/wav',
    List<Map<String, String>> subcategories = const [],
  }) async {
    final result = _results[_index];
    if (_index < _results.length - 1) _index++;
    return result;
  }
}

class _ImageParserReturning extends Fake implements ImageTransactionParser {
  _ImageParserReturning(this.result);
  final ParsedVoiceTransaction? result;

  @override
  Future<ParsedVoiceTransaction?> parse(String imagePath) async => result;
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  _FakeCurrencyNotifier(this._code);
  final String _code;

  @override
  Future<String> build() async => _code;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

_MockTransactionsRepo _makeTxRepo() {
  final repo = _MockTransactionsRepo();
  final now = DateTime(2026, 1, 1);
  when(() => repo.createTransaction(any())).thenAnswer(
    (_) async => TransactionModel(
      id: 'new-id',
      userId: 'u',
      amount: 10,
      type: TransactionType.expense,
      category: 'Comida',
      date: now,
      createdAt: now,
    ),
  );
  when(() => repo.updateTransaction(any())).thenAnswer(
    (_) async => TransactionModel(
      id: 'tx-1',
      userId: 'u',
      amount: 42.5,
      type: TransactionType.expense,
      category: 'Comida',
      date: now,
      createdAt: now,
    ),
  );
  when(() => repo.deleteTransaction(any())).thenAnswer((_) async {});
  return repo;
}

_MockRecurringRepo _makeRecurringRepo() {
  final repo = _MockRecurringRepo();
  when(() => repo.createRecurring(
        amount: any(named: 'amount'),
        type: any(named: 'type'),
        category: any(named: 'category'),
        subcategory: any(named: 'subcategory'),
        description: any(named: 'description'),
        recurrenceType: any(named: 'recurrenceType'),
        nextOccurrence: any(named: 'nextOccurrence'),
      )).thenAnswer((_) async => 'rec-id');
  when(() => repo.deleteRecurring(any())).thenAnswer((_) async {});
  when(() => repo.getById(any())).thenAnswer((_) async => null);
  when(() => repo.updateRecurring(
        id: any(named: 'id'),
        amount: any(named: 'amount'),
        type: any(named: 'type'),
        category: any(named: 'category'),
        subcategory: any(named: 'subcategory'),
        description: any(named: 'description'),
        recurrenceType: any(named: 'recurrenceType'),
        nextOccurrence: any(named: 'nextOccurrence'),
      )).thenAnswer((_) async {});
  return repo;
}

Widget _wrap({
  TransactionModel? transaction,
  ParsedVoiceTransaction? voiceData,
  _MockTransactionsRepo? txRepo,
  _MockRecurringRepo? recurringRepo,
  _MockSubRepo? subRepo,
  String currency = 'EUR',
  List<String>? quickCategories,
  VoiceInputGateway? voiceGateway,
  ImageInputGateway? imageGateway,
  VoiceTransactionParser? voiceParser,
  ImageTransactionParser? imageParser,
}) {
  SharedPreferences.setMockInitialValues({});
  final repo = subRepo ?? _MockSubRepo();
  when(() => repo.getForCategory(any(), any())).thenAnswer((_) async => []);

  final txR = txRepo ?? _makeTxRepo();
  final recR = recurringRepo ?? _makeRecurringRepo();

  return ProviderScope(
    overrides: [
      isProProvider.overrideWithValue(true),
      subcategoriesRepositoryProvider.overrideWithValue(repo),
      voiceInputGatewayProvider.overrideWithValue(
        voiceGateway ?? _FakeVoiceGateway(),
      ),
      imageInputGatewayProvider.overrideWithValue(
        imageGateway ?? _FakeImageGateway(),
      ),
      voiceTransactionParserProvider.overrideWithValue(
        voiceParser ?? _FakeVoiceParser(),
      ),
      imageTransactionParserProvider.overrideWithValue(
        imageParser ?? _FakeImageParser(),
      ),
      transactionsRepositoryProvider.overrideWithValue(txR),
      recurringTransactionsRepositoryProvider.overrideWithValue(recR),
      currencyProvider.overrideWith(() => _FakeCurrencyNotifier(currency)),
      customCategoriesSyncProvider.overrideWith(
        (ref) => <TransactionType, List<TransactionCategory>>{
          TransactionType.income: [],
          TransactionType.expense: [],
        },
      ),
      for (final type in TransactionType.values)
        quickCategoriesProvider(type).overrideWith(
            (_) async => quickCategories ?? const <String>[]),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: AddTransactionScreen(
        transaction: transaction,
        voiceData: voiceData,
      ),
    ),
  );
}

/// Taps the keypad submit key (✓), which saves directly in the single-screen
/// quick-entry flow.
Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.byIcon(PhosphorIcons.check).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(RecurrenceType.monthly);
    registerFallbackValue(
      TransactionModel(
        id: '',
        userId: '',
        amount: 0,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    );
  });

  // ── Basic render ─────────────────────────────────────────────────────────────

  testWidgets(
      'renders the type toggle, keypad, category strip and detail pills',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(quickCategories: ['Comida', 'Transporte']));
    await tester.pumpAndSettle();

    expect(find.byIcon(PhosphorIcons.trendUp), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.trendDown), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    // Quick category chips on the main screen
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    // Detail pills: date (Hoy), note, recurrence
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Nota'), findsOneWidget);
    expect(find.text('No repetir'), findsOneWidget);
  });

  testWidgets('renders the transaction amount when editing an existing one',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 42.5,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 3, 15),
        createdAt: DateTime(2026, 3, 15),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('42'), findsAtLeastNWidgets(1));
  });

  // ── Amount validation ────────────────────────────────────────────────────────

  testWidgets('shows invalid-amount error when saving with amount=0',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await _tapSave(tester);

    expect(find.byIcon(PhosphorIcons.warningCircle), findsOneWidget);
  });

  // ── Type toggle ──────────────────────────────────────────────────────────────

  testWidgets('type toggle switches between income and expense',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.trendUp));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.trendDown));
    await tester.pumpAndSettle();

    expect(find.byIcon(PhosphorIcons.trendUp), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.trendDown), findsOneWidget);
  });

  testWidgets('switching type clears the selected category', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();
    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
      quickCategories: ['Comida', 'Transporte'],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comida'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(PhosphorIcons.trendUp));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(PhosphorIcons.trendDown));
    await tester.pumpAndSettle();

    // Saving now must complain about the missing category.
    await tester.tap(find.text('5'));
    await tester.pump();
    await _tapSave(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    verifyNever(() => txRepo.createTransaction(any()));
  });

  // ── Edit mode ────────────────────────────────────────────────────────────────

  testWidgets('edit mode shows "Editar transacción" in app bar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 25,
        type: TransactionType.income,
        category: 'Salario',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Editar transacción'), findsOneWidget);
  });

  testWidgets('edit mode shows the delete button in the app bar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 25,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(PhosphorIcons.trash), findsOneWidget);
  });

  // ── Voice mode pre-populates ─────────────────────────────────────────────────

  testWidgets('voice mode pre-populates amount and category', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      voiceData: ParsedVoiceTransaction(
        amount: 15.0,
        type: TransactionType.expense,
        category: 'Comida',
        description: 'Café',
        date: DateTime(2026, 3, 1),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('15'), findsAtLeastNWidgets(1));
    // The parsed category is visible (prepended to the quick strip).
    expect(find.text('Comida'), findsOneWidget);
    // The parsed note shows up in its pill.
    expect(find.text('Café'), findsOneWidget);
  });

  // ── In-screen mic/camera buttons ──────────────────────────────────────────────

  testWidgets('mic and camera buttons are hidden while editing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 25,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(PhosphorIcons.microphone), findsNothing);
    expect(find.byIcon(PhosphorIcons.camera), findsNothing);
  });

  testWidgets(
      'tapping the mic button captures voice and fills the form in place',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      voiceGateway: _AutoVoiceGateway(),
      voiceParser: _VoiceParserReturning(const ParsedVoiceTransaction(
        amount: 20,
        type: TransactionType.expense,
        category: 'Comida',
        description: 'gasté 20 en comida',
      )),
    ));
    await tester.pumpAndSettle();

    // The fake gateway does real file IO (writes/reads a temp WAV), so this
    // needs runAsync to escape the fake test zone, with a real (not
    // fake-clock) delay to let that IO actually complete before pumping.
    // First tap starts recording, second tap stops it and processes.
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(PhosphorIcons.microphone));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.tap(find.byIcon(PhosphorIcons.stop));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('20'), findsAtLeastNWidgets(1));
    expect(find.text('Comida'), findsOneWidget);
  });

  // Regression: EXPENSE-MANAGER-1G — a PlatformException from the recording
  // backend starting to record went unhandled (hasPermission() had already
  // succeeded, so the app had no reason to expect a failure right after).
  // The mic UI should recover instead of leaving the screen stuck and
  // crashing.
  testWidgets(
      'start() throwing recorderNotAvailable resets the mic button '
      'instead of crashing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      voiceGateway: _StartThrowsVoiceGateway(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.microphone));
    await tester.pumpAndSettle();

    // No unhandled exception reaches the test zone (pumpAndSettle would fail
    // the test), the mic icon is back to its idle state, and the user gets
    // an actionable message instead of a silently stuck spinner.
    expect(find.byIcon(PhosphorIcons.microphone), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Micrófono no disponible'), findsOneWidget);
  });

  // Regression: an accidental instant tap (or a recording the backend
  // couldn't actually capture) used to reset the mic silently — the user
  // never learned their voice input wasn't understood.
  testWidgets(
      'a too-short recording shows an actionable message instead of '
      'silently resetting', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      voiceGateway: _TooShortRecordingVoiceGateway(),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(PhosphorIcons.microphone));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.tap(find.byIcon(PhosphorIcons.stop));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(find.byIcon(PhosphorIcons.microphone), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('No se pudo interpretar. Inténtalo de nuevo.'), findsOneWidget);
  });

  // Regression: _applyParsedTransaction only *set* _recurrenceType when the
  // new capture was recurring, never clearing it back to null otherwise —
  // so redoing a capture without a recurrence phrase kept the transaction
  // recurring from an earlier, discarded capture.
  testWidgets(
      're-tapping the mic without a recurrence phrase clears a previous one',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      voiceGateway: _AutoVoiceGateway(),
      voiceParser: _QueuedVoiceParser(const [
        ParsedVoiceTransaction(
          amount: 10,
          type: TransactionType.expense,
          category: 'Ocio',
          isRecurring: true,
          recurrenceType: 'monthly',
        ),
        ParsedVoiceTransaction(
          amount: 5,
          type: TransactionType.expense,
          category: 'Comida',
        ),
      ]),
    ));
    await tester.pumpAndSettle();

    // Each full capture is start-tap then stop-tap.
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(PhosphorIcons.microphone));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.tap(find.byIcon(PhosphorIcons.stop));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(find.text('Mensual'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(PhosphorIcons.microphone));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.tap(find.byIcon(PhosphorIcons.stop));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(find.text('No repetir'), findsOneWidget);
    expect(find.text('Mensual'), findsNothing);
  });

  testWidgets(
      'tapping the camera button opens the source sheet and fills the form',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      imageGateway: _AutoImageGateway(),
      imageParser: _ImageParserReturning(const ParsedVoiceTransaction(
        amount: 17.5,
        type: TransactionType.expense,
        category: 'Comida',
        description: 'Supermercado',
      )),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.camera));
    await tester.pumpAndSettle();

    // Source picker sheet (Cámara/Galería).
    expect(find.text('Galería'), findsOneWidget);
    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();

    expect(find.textContaining('17.5'), findsAtLeastNWidgets(1));
    expect(find.text('Supermercado'), findsOneWidget);
  });

  // ── Category required validation ─────────────────────────────────────────────

  testWidgets('save without category shows snackbar error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pump();
    await _tapSave(tester);

    expect(find.byType(SnackBar), findsOneWidget);
  });

  // ── Quick category strip ─────────────────────────────────────────────────────

  testWidgets('tapping a quick category chip selects it and allows saving',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();
    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
      quickCategories: ['Comida', 'Transporte'],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('Comida'));
    await tester.pumpAndSettle();
    await _tapSave(tester);

    final captured = verify(() => txRepo.createTransaction(captureAny()))
        .captured
        .first as TransactionModel;
    expect(captured.category, 'Comida');
    expect(captured.amount, 5);
  });

  testWidgets('the "Más" chip opens the full category picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(quickCategories: ['Comida']));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    // Category picker sheet shows its eyebrow title.
    expect(find.text('CATEGORÍA'), findsOneWidget);
  });

  // ── Detail pills: subcategory ────────────────────────────────────────────────

  testWidgets('subcategory pill visible after category is pre-selected',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final subRepo = _MockSubRepo();
    when(() => subRepo.getForCategory(any(), any()))
        .thenAnswer((_) async => ['Restaurante', 'Supermercado']);

    await tester.pumpWidget(_wrap(
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 10,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
      subRepo: subRepo,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Subcategor'), findsOneWidget);
  });

  // ── Detail pills: date ───────────────────────────────────────────────────────

  testWidgets('date pill opens the quick date sheet and "Ayer" updates it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDatePicker), findsOneWidget);

    await tester.tap(find.text('Ayer'));
    await tester.pumpAndSettle();

    expect(find.text('Ayer'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);
  });

  // ── Detail pills: note ───────────────────────────────────────────────────────

  testWidgets('note pill opens the note sheet and shows the saved text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nota'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Cena con amigos');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Cena con amigos'), findsOneWidget);
  });

  // ── Detail pills: recurrence ─────────────────────────────────────────────────

  testWidgets('recurrence pill opens the sheet and selecting Mensual '
      'activates it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('No repetir'));
    await tester.pumpAndSettle();

    // Sheet offers the frequency options.
    expect(find.text('Mensual'), findsOneWidget);
    expect(find.text('Semanal'), findsOneWidget);
    expect(find.text('Anual'), findsOneWidget);

    await tester.tap(find.text('Mensual'));
    await tester.pumpAndSettle();

    // Pill now reflects the active recurrence.
    expect(find.text('Mensual'), findsOneWidget);
    expect(find.text('No repetir'), findsNothing);
  });

  testWidgets('saving with recurrence creates a recurring transaction',
      (tester) async {
    // Wider surface: with a category selected the pill row holds four pills
    // (date, subcategory, note, recurrence) and is horizontally scrollable.
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final recRepo = _makeRecurringRepo();
    await tester.pumpWidget(_wrap(
      recurringRepo: recRepo,
      voiceData: ParsedVoiceTransaction(
        amount: 12.0,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 3, 1),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No repetir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mensual'));
    await tester.pumpAndSettle();

    await _tapSave(tester);

    verify(() => recRepo.createRecurring(
          amount: any(named: 'amount'),
          type: any(named: 'type'),
          category: any(named: 'category'),
          subcategory: any(named: 'subcategory'),
          description: any(named: 'description'),
          recurrenceType: RecurrenceType.monthly,
          nextOccurrence: any(named: 'nextOccurrence'),
        )).called(1);
  });

  // ── New transaction save flow ────────────────────────────────────────────────

  testWidgets('save expense creates transaction via repo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();

    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
      voiceData: ParsedVoiceTransaction(
        amount: 10.0,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 3, 1),
      ),
    ));
    await tester.pumpAndSettle();

    await _tapSave(tester);

    verify(() => txRepo.createTransaction(any())).called(1);
  });

  testWidgets('save income creates transaction with income type',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();

    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
      voiceData: ParsedVoiceTransaction(
        amount: 500.0,
        type: TransactionType.income,
        category: 'Salario',
        date: DateTime(2026, 3, 1),
      ),
    ));
    await tester.pumpAndSettle();

    await _tapSave(tester);

    final captured = verify(() => txRepo.createTransaction(captureAny()))
        .captured
        .first as TransactionModel;
    expect(captured.type, TransactionType.income);
  });

  // ── Edit save flow ───────────────────────────────────────────────────────────

  testWidgets('edit mode save calls updateTransaction', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();

    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 42.5,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 3, 15),
        createdAt: DateTime(2026, 3, 15),
      ),
    ));
    await tester.pumpAndSettle();

    await _tapSave(tester);

    verify(() => txRepo.updateTransaction(any())).called(1);
  });

  // ── Delete flow ──────────────────────────────────────────────────────────────

  testWidgets('delete button shows confirm dialog and calls deleteTransaction',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final txRepo = _makeTxRepo();
    final recRepo = _makeRecurringRepo();

    await tester.pumpWidget(_wrap(
      txRepo: txRepo,
      recurringRepo: recRepo,
      transaction: TransactionModel(
        id: 'tx-1',
        userId: 'u',
        amount: 25,
        type: TransactionType.expense,
        category: 'Comida',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.trash));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    final dialogDeleteBtns = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Eliminar'),
    );
    await tester.tap(dialogDeleteBtns.last);
    await tester.pumpAndSettle();

    verify(() => txRepo.deleteTransaction('tx-1')).called(1);
  });
}
