import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Thin abstraction over `package:google_mlkit_text_recognition` so the
/// receipt-parsing flow can be tested without the platform plugin — same
/// pattern as [VoiceInputGateway]/[ImageInputGateway].
abstract interface class ReceiptOcrGateway {
  /// Recognizes text in the image at [imagePath] and returns it as a list
  /// of non-empty lines, top to bottom.
  Future<List<String>> recognizeLines(String imagePath);
}

class MlKitReceiptOcrGateway implements ReceiptOcrGateway {
  MlKitReceiptOcrGateway() : _recognizer = TextRecognizer();
  final TextRecognizer _recognizer;

  @override
  Future<List<String>> recognizeLines(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);
    return result.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

final receiptOcrGatewayProvider = Provider<ReceiptOcrGateway>((ref) {
  return MlKitReceiptOcrGateway();
});
