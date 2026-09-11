import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/core/services/voice_input_gateway.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/voice_transaction_button.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../../../helpers/mocks.dart';

Widget _wrap({
  required MockVoiceTransactionParser parser,
  required MockVoiceInputGateway voice,
}) =>
    ProviderScope(
      overrides: [
        voiceTransactionParserProvider.overrideWithValue(parser),
        voiceInputGatewayProvider.overrideWithValue(voice),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: const Scaffold(
          floatingActionButton: VoiceTransactionButton(),
        ),
      ),
    );

void main() {
  setUpAll(() {
    registerCommonFallbacks();
    registerFallbackValue('');
  });

  late MockVoiceTransactionParser parser;
  late MockVoiceInputGateway voice;

  setUp(() {
    parser = MockVoiceTransactionParser();
    voice = MockVoiceInputGateway();
    // Default: gateway gracefully handles a stop() call (called in dispose).
    when(() => voice.stop()).thenAnswer((_) async {});
  });

  testWidgets('idle state renders the mic icon', (tester) async {
    await tester.pumpWidget(_wrap(parser: parser, voice: voice));
    // The pulse animation in _VoiceState.listening repeats forever, so
    // pumpAndSettle would time out. A single pump() is enough to draw the
    // initial idle frame.
    await tester.pump();

    expect(find.byIcon(PhosphorIcons.microphone()), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('idle state shows no progress indicator or stop icon',
      (tester) async {
    await tester.pumpWidget(_wrap(parser: parser, voice: voice));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(PhosphorIcons.stop()), findsNothing);
  });

  testWidgets(
      'tap on idle FAB → initialises the mic and enters listening state',
      (tester) async {
    when(() => voice.initialize(onError: any(named: 'onError')))
        .thenAnswer((_) async => true);
    when(() => voice.listen(
          localeId: any(named: 'localeId'),
          onResult: any(named: 'onResult'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(parser: parser, voice: voice));
    await tester.pump();

    await tester.tap(find.byIcon(PhosphorIcons.microphone()));
    await tester.pump(); // start the async call
    await tester.pump(); // settle the state change

    verify(() => voice.initialize(onError: any(named: 'onError'))).called(1);
    verify(() => voice.listen(
          localeId: any(named: 'localeId'),
          onResult: any(named: 'onResult'),
        )).called(1);

    // Listening UI: stop icon + pulse-wrapped FAB.
    expect(find.byIcon(PhosphorIcons.stop()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.microphone()), findsNothing);
  });

  testWidgets('tap while listening stops the mic', (tester) async {
    when(() => voice.initialize(onError: any(named: 'onError')))
        .thenAnswer((_) async => true);
    when(() => voice.listen(
          localeId: any(named: 'localeId'),
          onResult: any(named: 'onResult'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(parser: parser, voice: voice));
    await tester.pump();

    // Enter listening state.
    await tester.tap(find.byIcon(PhosphorIcons.microphone()));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(PhosphorIcons.stop()), findsOneWidget);

    // Tap again to stop.
    await tester.tap(find.byIcon(PhosphorIcons.stop()));
    await tester.pump();

    verify(() => voice.stop()).called(greaterThanOrEqualTo(1));
  });

  testWidgets(
      'mic unavailable → shows snackbar and stays in idle state',
      (tester) async {
    when(() => voice.initialize(onError: any(named: 'onError')))
        .thenAnswer((_) async => false);

    await tester.pumpWidget(_wrap(parser: parser, voice: voice));
    await tester.pump();

    await tester.tap(find.byIcon(PhosphorIcons.microphone()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Spanish micUnavailable message
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.microphone()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.stop()), findsNothing);
  });
}
