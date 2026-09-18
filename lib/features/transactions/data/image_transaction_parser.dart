import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/services/receipt_ocr_gateway.dart';
import 'package:expense_manager/core/utils/image_mime_detector.dart';
import 'package:expense_manager/features/transactions/domain/parsed_voice_transaction.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'local_nlp/category_matcher.dart';
import 'local_nlp/receipt_amount_finder.dart';

/// Parses a photographed receipt into transaction fields entirely
/// on-device: OCR ([ReceiptOcrGateway]) extracts the printed text, then
/// keyword heuristics ([ReceiptAmountFinder]/[CategoryMatcher]) find the
/// total and guess a category. No AI/network call — precision is
/// intentionally traded for privacy and zero cost, so results always land
/// in the editable add-transaction sheet for the user to confirm.
class ImageTransactionParser {
  ImageTransactionParser(this._ocr);

  final ReceiptOcrGateway _ocr;

  Future<ParsedVoiceTransaction?> parse(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    if (!ImageMimeDetector.isValidImage(bytes)) return null;

    final lines = await _ocr.recognizeLines(imagePath);
    if (lines.isEmpty) return null;

    final amount = ReceiptAmountFinder.find(lines);
    if (amount == null || amount <= 0) return null;

    final category =
        CategoryMatcher.match(lines.join(' '), TransactionType.expense);

    return ParsedVoiceTransaction(
      amount: amount,
      type: TransactionType.expense,
      category: category,
      description: lines.first,
    );
  }
}

final imageTransactionParserProvider = Provider<ImageTransactionParser>((ref) {
  return ImageTransactionParser(ref.watch(receiptOcrGatewayProvider));
});
