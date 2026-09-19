import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/local_nlp/receipt_amount_finder.dart';

void main() {
  group('ReceiptAmountFinder', () {
    test('finds the amount on a line naming the total', () {
      expect(
        ReceiptAmountFinder.find(['Tienda', 'Menu 15,00', 'TOTAL 42,50']),
        42.5,
      );
    });

    test('checks the following line when the keyword line has no number', () {
      expect(
        ReceiptAmountFinder.find(['Tienda', 'TOTAL A PAGAR', '42,50']),
        42.5,
      );
    });

    test('falls back to the largest amount when no keyword line matches', () {
      expect(
        ReceiptAmountFinder.find(['Tienda', '3 x 2,00', '6,00']),
        6,
      );
    });

    test('returns null when no numbers are present at all', () {
      expect(ReceiptAmountFinder.find(['Tienda', 'Gracias']), isNull);
    });

    test('recognizes total keywords in en/fr/de too', () {
      expect(ReceiptAmountFinder.find(['Shop', 'Amount due 9,99']), 9.99);
      expect(ReceiptAmountFinder.find(['Magasin', 'Montant 9,99']), 9.99);
      expect(ReceiptAmountFinder.find(['Geschaeft', 'Gesamtbetrag 9,99']), 9.99);
    });

    // Regression: real on-device ML Kit output for tool/qa/fixtures/test_receipt.jpg
    // misread "TOTAL" as "'IOTAL" and put every line item's price in its own
    // trailing block, separate from the item labels — so the keyword search
    // never matches, and a naive "largest number anywhere" fallback picked
    // the receipt's date year (2026) over the real total (17.50).
    test('ignores years/ticket numbers/times when the total keyword is misread',
        () {
      final ocrLines = [
        'SUPERMERCADO QA',
        'Fecha: 2026-09-15',
        'Tickct: 000123',
        'Avenica ce Pruebas 123',
        '1 x Pan integral',
        '1',
        '2 x Leche enlere',
        'x Manzanas',
        "'IOTAL",
        '1 x Det.ergent.e',
        'Hodi 12:34',
        '2.50',
        '3.20',
        '4.80',
        '7.00',
        '17.50',
        'Gracias por su compra',
      ];
      expect(ReceiptAmountFinder.find(ocrLines), 17.50);
    });

    // Regression: 'total' (keyword) is a substring of 'subtotal', so a
    // standard receipt with Subtotal printed before Total matched the
    // subtotal line first and returned the pre-tax amount.
    test('does not treat a Subtotal line as the Total', () {
      expect(
        ReceiptAmountFinder.find(
          ['Tienda', 'Subtotal 15,00', 'IVA 2,50', 'Total 17,50'],
        ),
        17.50,
      );
    });

    // Regression: amounts were parsed with every '.'/',' treated as a
    // decimal separator, so a thousands-grouped total like "1.234,56" (or
    // "12.345,67") was truncated to its last few digits.
    test('parses a thousands-grouped total correctly', () {
      expect(
        ReceiptAmountFinder.find(['Tienda', 'TOTAL 1.234,56']),
        1234.56,
      );
    });
  });
}
