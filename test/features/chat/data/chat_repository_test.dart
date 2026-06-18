import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/utils/ai_rate_limiter.dart';
import 'package:expense_manager/features/chat/data/chat_repository.dart';
import 'package:expense_manager/features/chat/domain/chat_message.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/supabase_function_helper.dart';

void main() {
  setUpAll(registerCommonFallbacks);

  late MockSupabaseClient supabase;
  late MockFunctionsClient functions;
  late ChatRepository repo;

  setUp(() {
    AiRateLimiter.instance.reset();
    supabase = MockSupabaseClient();
    functions = MockFunctionsClient();
    when(() => supabase.functions).thenReturn(functions);
    repo = ChatRepository(supabase);
  });

  // ── Happy path ───────────────────────────────────────────────────────────

  group('sendMessage — happy path', () {
    test('returns the AI reply when status is 200', () async {
      stubFunctionInvoke(
        functions,
        functionName: 'chat-transactions',
        response: okFunctionResponse({'reply': '¡Hola! ¿En qué te ayudo?'}),
      );

      final reply = await repo.sendMessage(
        message: 'Hola',
        history: const [],
        locale: 'es',
      );

      expect(reply, '¡Hola! ¿En qué te ayudo?');
    });

    test('serialises history into role/content pairs', () async {
      final captured = <Object?>[];
      when(
        () => functions.invoke('chat-transactions', body: any(named: 'body')),
      ).thenAnswer((invocation) async {
        captured.add(invocation.namedArguments[#body]);
        return okFunctionResponse({'reply': 'ok'});
      });

      final now = DateTime(2026);
      final history = [
        ChatMessage(content: 'p1', isUser: true, timestamp: now),
        ChatMessage(content: 'r1', isUser: false, timestamp: now),
      ];

      await repo.sendMessage(message: 'p2', history: history, locale: 'en');

      final body = captured.single as Map<String, dynamic>;
      expect(body['message'], 'p2');
      expect(body['locale'], 'en');

      final h = body['history'] as List;
      expect(h, hasLength(2));
      expect(h[0], {'role': 'user', 'content': 'p1'});
      expect(h[1], {'role': 'assistant', 'content': 'r1'});
    });
  });

  // ── Server-side failures ─────────────────────────────────────────────────

  group('sendMessage — failures', () {
    test('throws ServerFailure with server message when FunctionException has error detail',
        () async {
      stubFunctionInvokeError(
        functions,
        error: FunctionException(
          status: 502,
          details: {'error': 'AI service temporarily unavailable. Please try again.'},
        ),
      );

      await expectLater(
        () => repo.sendMessage(message: 'm', history: const [], locale: 'es'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.message,
            'message',
            'AI service temporarily unavailable. Please try again.',
          ),
        ),
      );
    });

    test('throws ServerFailure with status code when FunctionException has no error detail',
        () async {
      stubFunctionInvokeError(
        functions,
        error: FunctionException(status: 500, details: 'Internal server error'),
      );

      await expectLater(
        () => repo.sendMessage(message: 'm', history: const [], locale: 'es'),
        throwsA(
          isA<ServerFailure>()
              .having((f) => f.message, 'message', contains('500')),
        ),
      );
    });

    test('throws RateLimitFailure on 429 FunctionException', () async {
      stubFunctionInvokeError(
        functions,
        error: FunctionException(
          status: 429,
          details: {'error': 'Rate limit exceeded. Maximum 20 messages per hour.'},
        ),
      );

      await expectLater(
        () => repo.sendMessage(message: 'm', history: const [], locale: 'es'),
        throwsA(isA<RateLimitFailure>()),
      );
    });

    test('throws ServerFailure when reply is null', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({'reply': null}),
      );

      expect(
        () => repo.sendMessage(message: 'm', history: const [], locale: 'es'),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('throws ServerFailure when reply is empty', () async {
      stubFunctionInvoke(
        functions,
        response: okFunctionResponse({'reply': ''}),
      );

      expect(
        () => repo.sendMessage(message: 'm', history: const [], locale: 'es'),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('throws ServerFailure when response data is not a Map', () async {
      stubFunctionInvoke(
        functions,
        response: functionResponseWith(status: 200, data: 'unexpected string'),
      );

      expect(
        () => repo.sendMessage(message: 'm', history: const [], locale: 'es'),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('wraps unexpected exceptions as NetworkFailure', () async {
      stubFunctionInvokeError(
        functions,
        error: Exception('boom'),
      );

      expect(
        () => repo.sendMessage(message: 'm', history: const [], locale: 'es'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('rethrows AppFailure subtypes without wrapping', () async {
      stubFunctionInvokeError(
        functions,
        error: const ServerFailure('original'),
      );

      await expectLater(
        () => repo.sendMessage(message: 'm', history: const [], locale: 'es'),
        throwsA(
          isA<ServerFailure>().having((f) => f.message, 'message', 'original'),
        ),
      );
    });
  });

  // ── Rate limiting ───────────────────────────────────────────────────────

  group('rate limiting', () {
    test('throws RateLimitFailure after maxPerMinute calls', () async {
      for (var i = 0; i < AiRateLimiter.maxPerMinute; i++) {
        AiRateLimiter.instance.tryConsume();
      }

      expect(
        () => repo.sendMessage(message: 'm', history: const [], locale: 'es'),
        throwsA(isA<RateLimitFailure>()),
      );
    });
  });
}
