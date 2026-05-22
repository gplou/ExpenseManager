import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/utils/ai_rate_limiter.dart';
import 'package:expense_manager/features/transactions/data/image_transaction_parser.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/supabase_function_helper.dart';

/// Minimum valid JPEG bytes (SOI + APP0 + EOI). Just enough to satisfy
/// `ImageMimeDetector.detect` so we can exercise the upload path.
final Uint8List _jpegBytes = Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, // SOI + APP0 header
  0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
  0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
  0xFF, 0xD9, // EOI
]);

final Uint8List _notAnImage = Uint8List.fromList([0, 1, 2, 3, 4, 5]);

void main() {
  setUpAll(registerCommonFallbacks);

  late MockSupabaseClient supabase;
  late MockFunctionsClient functions;
  late ImageTransactionParser parser;

  setUp(() {
    AiRateLimiter.instance.reset();
    supabase = MockSupabaseClient();
    functions = MockFunctionsClient();
    when(() => supabase.functions).thenReturn(functions);
    parser = ImageTransactionParser(supabase);
  });

  // ── Pre-flight validation ────────────────────────────────────────────────

  group('parse — input validation', () {
    test('returns null when image bytes are too large (>4 MB)', () async {
      final huge = Uint8List(4 * 1024 * 1024 + 1);
      final result = await parser.parse(huge);
      expect(result, isNull);
      verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
    });

    test('returns null when bytes are not a recognised image', () async {
      final result = await parser.parse(_notAnImage);
      expect(result, isNull);
      verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
    });
  });

  // ── Happy paths ──────────────────────────────────────────────────────────

  group('parse — happy paths', () {
    test('returns ParsedVoiceTransaction with valid amount', () async {
      stubFunctionInvoke(
        functions,
        functionName: 'parse-image-transaction',
        response: okFunctionResponse({
          'result':
              '{"amount":42.5,"type":"expense","category":"Comida","description":"Restaurante"}',
        }),
      );

      final result = await parser.parse(_jpegBytes);

      expect(result, isNotNull);
      expect(result!.amount, 42.5);
      expect(result.category, 'Comida');
      expect(result.description, 'Restaurante');
    });
  });

  // ── Server-side failures ─────────────────────────────────────────────────

  group('parse — failures', () {
    test('returns null when AI returns amount <= 0', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({
          'result': '{"amount":0,"type":"expense","category":"Otros"}',
        }),
      );

      final result = await parser.parse(_jpegBytes);
      expect(result, isNull);
    });

    test('returns null when status is not 200', () async {
      stubFunctionInvoke(
        functions,
        response: functionResponseWith(status: 500, data: <String, dynamic>{}),
      );

      final result = await parser.parse(_jpegBytes);
      expect(result, isNull);
    });

    test('returns null when result JSON is malformed', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({'result': 'not-json'}),
      );

      final result = await parser.parse(_jpegBytes);
      expect(result, isNull);
    });
  });

  // ── Rate limiting ───────────────────────────────────────────────────────

  group('rate limiting', () {
    test('throws RateLimitFailure when over the quota', () async {
      for (var i = 0; i < AiRateLimiter.maxPerMinute; i++) {
        AiRateLimiter.instance.tryConsume();
      }

      expect(
        () => parser.parse(_jpegBytes),
        throwsA(isA<RateLimitFailure>()),
      );
    });
  });
}
