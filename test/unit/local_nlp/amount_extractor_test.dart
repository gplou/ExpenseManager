import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/local_nlp/amount_extractor.dart';

void main() {
  group('AmountExtractor', () {
    test('extractAll returns every number in order', () {
      expect(
        AmountExtractor.extractAll('3 cafés a 2,50 cada uno, total 7,50'),
        [3, 2.5, 7.5],
      );
    });

    test('extractAll returns empty list when no digits are present', () {
      expect(AmountExtractor.extractAll('sin números aquí'), isEmpty);
    });

    test('firstIn picks the first number mentioned', () {
      expect(AmountExtractor.firstIn('gasté 20 en comida, quedan 5'), 20);
    });

    test('firstIn returns null when nothing is found', () {
      expect(AmountExtractor.firstIn('nada'), isNull);
    });

    test('largestIn picks the biggest number found', () {
      expect(AmountExtractor.largestIn('2,00 3 x 15,50 total'), 15.5);
    });

    test('treats both comma and dot as decimal separators', () {
      expect(AmountExtractor.extractAll('20,50 y 20.50'), [20.5, 20.5]);
    });

    test('plain integers parse without a fractional part', () {
      expect(AmountExtractor.firstIn('1500 de nómina'), 1500);
    });

    // Regression: a naive "any '.'/',' is a decimal separator" rule
    // truncated thousands-grouped amounts to their last 1-2 digits
    // (e.g. "1.234,56" -> 4.56 instead of 1234.56).
    group('thousands separators', () {
      test('es/fr/de grouping (dot thousands, comma decimal)', () {
        expect(AmountExtractor.firstIn('TOTAL 1.234,56'), 1234.56);
        expect(AmountExtractor.firstIn('pagué 1.500 en alquiler'), 1500);
      });

      test('en grouping (comma thousands, dot decimal)', () {
        expect(AmountExtractor.firstIn('paid 1,234.56 for rent'), 1234.56);
        expect(AmountExtractor.firstIn('1,500 attendees'), 1500);
      });

      test('does not affect plain small decimals', () {
        expect(AmountExtractor.extractAll('2.50 3.20 4.80 7.00 17.50'),
            [2.5, 3.2, 4.8, 7.0, 17.5]);
      });
    });
  });
}
