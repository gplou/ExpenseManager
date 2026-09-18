import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

import '../../../helpers/mocks.dart';

/// Minimum valid JPEG bytes (SOI + APP0 + EOI) — just enough to satisfy
/// `ImageMimeDetector.detect` so we can exercise the OCR path.
const _jpegBytes = [
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, // SOI + APP0 header
  0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
  0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
  0xFF, 0xD9, // EOI
];

void main() {
  setUpAll(registerCommonFallbacks);

  late MockReceiptOcrGateway ocr;
  late ImageTransactionParser parser;
  late File jpegFile;
  late File notAnImageFile;

  setUp(() async {
    ocr = MockReceiptOcrGateway();
    parser = ImageTransactionParser(ocr);

    final dir = Directory.systemTemp;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    jpegFile = File('${dir.path}/receipt_$stamp.jpg');
    await jpegFile.writeAsBytes(_jpegBytes);
    notAnImageFile = File('${dir.path}/not_an_image_$stamp.txt');
    await notAnImageFile.writeAsBytes([0, 1, 2, 3, 4, 5]);
  });

  tearDown(() async {
    if (await jpegFile.exists()) await jpegFile.delete();
    if (await notAnImageFile.exists()) await notAnImageFile.delete();
  });

  group('parse — input validation', () {
    test('returns null when the file is not a recognised image', () async {
      final result = await parser.parse(notAnImageFile.path);
      expect(result, isNull);
      verifyNever(() => ocr.recognizeLines(any()));
    });
  });

  group('parse — OCR results', () {
    test('returns null when OCR finds no text', () async {
      when(() => ocr.recognizeLines(jpegFile.path))
          .thenAnswer((_) async => const []);

      final result = await parser.parse(jpegFile.path);
      expect(result, isNull);
    });

    test('returns null when no amount can be found', () async {
      when(() => ocr.recognizeLines(jpegFile.path)).thenAnswer(
        (_) async => const ['Mi Tienda', 'Gracias por su compra'],
      );

      final result = await parser.parse(jpegFile.path);
      expect(result, isNull);
    });

    test('returns null when the detected total is zero', () async {
      when(() => ocr.recognizeLines(jpegFile.path))
          .thenAnswer((_) async => const ['Mi Tienda', 'TOTAL 0']);

      final result = await parser.parse(jpegFile.path);
      expect(result, isNull);
    });

    test('extracts total near a "total" keyword and uses the first line as description',
        () async {
      when(() => ocr.recognizeLines(jpegFile.path)).thenAnswer(
        (_) async => const [
          'Restaurante El Sol',
          'Menu del dia 15,00',
          'TOTAL 42,50',
        ],
      );

      final result = await parser.parse(jpegFile.path);
      expect(result, isNotNull);
      expect(result!.amount, 42.5);
      expect(result.description, 'Restaurante El Sol');
      expect(result.type, TransactionType.expense);
    });

    test('falls back to the largest amount when no total keyword is found',
        () async {
      when(() => ocr.recognizeLines(jpegFile.path)).thenAnswer(
        (_) async => const ['Tienda', '3 x 2,00', '6,00'],
      );

      final result = await parser.parse(jpegFile.path);
      expect(result!.amount, 6);
    });

    test('guesses a category from the receipt text', () async {
      when(() => ocr.recognizeLines(jpegFile.path)).thenAnswer(
        (_) async => const ['Farmacia Central', 'TOTAL 12,30'],
      );

      final result = await parser.parse(jpegFile.path);
      expect(result!.category, 'Salud');
    });

    test('falls back to Otros when nothing matches', () async {
      when(() => ocr.recognizeLines(jpegFile.path)).thenAnswer(
        (_) async => const ['XYZ123', 'TOTAL 12,30'],
      );

      final result = await parser.parse(jpegFile.path);
      expect(result!.category, 'Otros');
    });
  });
}
