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

      final result = await parser.parse('café cinco euros');

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

      final result = await parser.parse('cobré mil quinientos del trabajo');

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

      final result = await parser.parse('tres euros');

      expect(result, isNotNull);
      expect(result!.amount, 3);
    });
  });

  // ── Failure modes ────────────────────────────────────────────────────────

  group('parse — failures', () {
    test('returns null when status is not 200', () async {
      stubFunctionInvoke(
        functions,
        response: functionResponseWith(status: 500, data: {'result': null}),
      );

      final result = await parser.parse('algo');

      expect(result, isNull);
    });

    test('returns null when result is not valid JSON', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({'result': 'not json at all'}),
      );

      final result = await parser.parse('texto');

      expect(result, isNull);
    });

    test('returns null when result field is missing', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({'other': 'field'}),
      );

      final result = await parser.parse('texto');

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
        await parser.parse('call $i');
      }

      // Next call should be rate-limited
      expect(
        () => parser.parse('one too many'),
        throwsA(isA<RateLimitFailure>()),
      );
    });

    test('does not call the edge function when rate-limited', () async {
      // Fill the quota by calling tryConsume directly
      for (var i = 0; i < AiRateLimiter.maxPerMinute; i++) {
        AiRateLimiter.instance.tryConsume();
      }

      try {
        await parser.parse('blocked');
      } on RateLimitFailure {
        // expected
      }

      verifyNever(
        () => functions.invoke(any(), body: any(named: 'body')),
      );
    });
  });
}
