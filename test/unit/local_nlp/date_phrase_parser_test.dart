import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/local_nlp/date_phrase_parser.dart';

import '../../helpers/clock_helper.dart';

void main() {
  group('DatePhraseParser', () {
    test('resolves "hoy"/"today" to the current date', () {
      withFixedClock(DateTime(2026, 3, 10), () {
        expect(DatePhraseParser.resolve('hoy gasté 10', 'es'), DateTime(2026, 3, 10));
        expect(DatePhraseParser.resolve('spent 10 today', 'en'), DateTime(2026, 3, 10));
      });
    });

    test('resolves "ayer"/"yesterday" to the previous date', () {
      withFixedClock(DateTime(2026, 3, 10), () {
        expect(DatePhraseParser.resolve('ayer gasté 10', 'es'), DateTime(2026, 3, 9));
        expect(DatePhraseParser.resolve('spent 10 yesterday', 'en'), DateTime(2026, 3, 9));
      });
    });

    test('resolves a weekday name to its most recent past occurrence', () {
      // 2026-03-10 is a Tuesday.
      withFixedClock(DateTime(2026, 3, 10), () {
        expect(DatePhraseParser.resolve('el lunes gasté 10', 'es'), DateTime(2026, 3, 9));
        expect(DatePhraseParser.resolve('spent 10 on monday', 'en'), DateTime(2026, 3, 9));
      });
    });

    test('resolving the current weekday returns today', () {
      // 2026-03-10 is a Tuesday.
      withFixedClock(DateTime(2026, 3, 10), () {
        expect(DatePhraseParser.resolve('el martes gasté 10', 'es'), DateTime(2026, 3, 10));
      });
    });

    test('returns null when no date phrase is recognized', () {
      withFixedClock(DateTime(2026, 3, 10), () {
        expect(DatePhraseParser.resolve('gasté 10 en comida', 'es'), isNull);
      });
    });

    test('works for fr/de locales', () {
      withFixedClock(DateTime(2026, 3, 10), () {
        expect(DatePhraseParser.resolve('hier 10 euros', 'fr'), DateTime(2026, 3, 9));
        expect(DatePhraseParser.resolve('gestern 10 euro', 'de'), DateTime(2026, 3, 9));
      });
    });
  });
}
