import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/presentation/widgets/voice_transaction_button.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

import '../../../helpers/mocks.dart';

Widget _wrap(MockVoiceTransactionParser parser) => ProviderScope(
      overrides: [
        voiceTransactionParserProvider.overrideWithValue(parser),
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
  late MockVoiceTransactionParser parser;

  setUp(() {
    parser = MockVoiceTransactionParser();
  });

  testWidgets('idle state renders the mic icon', (tester) async {
    await tester.pumpWidget(_wrap(parser));
    // The pulse animation in _VoiceState.listening repeats forever, so
    // pumpAndSettle would time out. A single pump() is enough to draw the
    // initial idle frame.
    await tester.pump();

    expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('idle state shows no progress indicator or stop icon',
      (tester) async {
    await tester.pumpWidget(_wrap(parser));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });
}
