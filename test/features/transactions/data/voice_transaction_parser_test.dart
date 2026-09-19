import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/utils/ai_rate_limiter.dart';
import 'package:expense_manager/features/transactions/data/voice_transaction_parser.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/supabase_function_helper.dart';

void main() {
  setUpAll(registerCommonFallbacks);

  late MockSupabaseClient supabase;
  late MockFunctionsClient functions;
  late VoiceTransactionParser parser;
  final audioBytes = Uint8List.fromList(List.filled(100, 1));

  setUp(() {
    AiRateLimiter.instance.reset();
    supabase = MockSupabaseClient();
    functions = MockFunctionsClient();
    when(() => supabase.functions).thenReturn(functions);
    parser = VoiceTransactionParser(supabase);
  });

  // ── Happy paths ──────────────────────────────────────────────────────────

  group('parse — happy paths', () {
    test('returns ParsedVoiceTransaction with all fields when AI replies OK',
        () async {
      stubFunctionInvoke(
        functions,
        functionName: 'parse-voice-transaction',
        response: okFunctionResponse({
          'result':
              '{"amount":12.5,"type":"expense","category":"Comida","description":"café"}',
        }),
      );

      final result = await parser.parse(audioBytes);

      expect(result, isNotNull);
      expect(result!.amount, 12.5);
      expect(result.type, TransactionType.expense);
      expect(result.category, 'Comida');
      expect(result.description, 'café');
    });

    test('maps type=income correctly', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({
          'result': '{"amount":1500,"type":"income","category":"Salario"}',
        }),
      );

      final result = await parser.parse(audioBytes);

      expect(result!.type, TransactionType.income);
      expect(result.amount, 1500);
    });

    test('parses AI response wrapped in ```json fences', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({
          'result':
              '```json\n{"amount":3,"type":"expense","category":"Otros"}\n```',
        }),
      );

      final result = await parser.parse(audioBytes);

      expect(result, isNotNull);
      expect(result!.amount, 3);
    });

    test('sends the audio as base64 with the given mime type', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({
          'result': '{"amount":1,"type":"expense","category":"Otros"}',
        }),
      );

      await parser.parse(audioBytes, mimeType: 'audio/wav');

      final captured = verify(() => functions.invoke(
            'parse-voice-transaction',
            body: captureAny(named: 'body'),
          )).captured.single as Map<String, dynamic>;
      expect(captured['mime_type'], 'audio/wav');
      expect(captured['audio_base64'], isA<String>());
    });
  });

  // ── Failure modes ────────────────────────────────────────────────────────

  group('parse — failures', () {
    test('returns null when status is not 200', () async {
      stubFunctionInvoke(
        functions,
        response: functionResponseWith(status: 500, data: {'result': null}),
      );

      final result = await parser.parse(audioBytes);

      expect(result, isNull);
    });

    test('returns null when result is not valid JSON', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({'result': 'not json at all'}),
      );

      final result = await parser.parse(audioBytes);

      expect(result, isNull);
    });

    test('returns null when result field is missing', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({'other': 'field'}),
      );

      final result = await parser.parse(audioBytes);

      expect(result, isNull);
    });

    // Regression: the on-device parser used to reject amount<=0, but the
    // AI-based fromAiJson factory doesn't — Gemini returns amount:0 when it
    // heard nothing transaction-like, and that must still surface as "not
    // understood" rather than opening the form on a zero amount.
    test('returns null when the AI reports amount 0 (nothing understood)',
        () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({
          'result':
              '{"amount":0,"type":"expense","category":"Otros","description":""}',
        }),
      );

      final result = await parser.parse(audioBytes);

      expect(result, isNull);
    });
  });

  // ── Rate limiting ───────────────────────────────────────────────────────

  group('rate limiting', () {
    test('throws RateLimitFailure after maxPerMinute calls', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({
          'result': '{"amount":1,"type":"expense","category":"Otros"}',
        }),
      );

      // Drain the quota
      for (var i = 0; i < AiRateLimiter.maxPerMinute; i++) {
        await parser.parse(audioBytes);
      }

      // Next call should be rate-limited
      expect(
        () => parser.parse(audioBytes),
        throwsA(isA<RateLimitFailure>()),
      );
    });

    test('does not call the edge function when rate-limited', () async {
      // Fill the quota by calling tryConsume directly
      for (var i = 0; i < AiRateLimiter.maxPerMinute; i++) {
        AiRateLimiter.instance.tryConsume();
      }

      try {
        await parser.parse(audioBytes);
      } on RateLimitFailure {
        // expected
      }

      verifyNever(
        () => functions.invoke(any(), body: any(named: 'body')),
      );
    });
  });
}
