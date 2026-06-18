import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/core/utils/ai_rate_limiter.dart';
import 'package:expense_manager/features/chat/domain/chat_message.dart';
import 'package:expense_manager/core/utils/app_logger.dart';

class ChatRepository {
  ChatRepository(this._client);
  final SupabaseClient _client;

  static const String _function = 'chat-transactions';

  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
    required String locale,
  }) async {
    if (!AiRateLimiter.instance.tryConsume()) {
      throw const RateLimitFailure(
        'Rate limit reached: max ${AiRateLimiter.maxPerMinute} uses per minute. Please wait.',
      );
    }

    try {
      final historyPayload = history.map((m) {
        return <String, String>{
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.content,
        };
      }).toList();

      final response = await _client.functions.invoke(
        _function,
        body: {
          'message': message,
          'history': historyPayload,
          'locale': locale,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final reply = data['reply'] as String?;
      if (reply == null || reply.isEmpty) {
        throw const ServerFailure('No response received from AI');
      }

      return reply;
    } on AppFailure {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      final serverError = details is Map ? details['error'] as String? : null;
      if (e.status == 429) {
        throw RateLimitFailure(serverError ?? 'Rate limit exceeded');
      }
      throw ServerFailure(serverError ?? 'AI service error (${e.status})');
    } catch (e, st) {
      AppLogger.log('ChatRepository error: $e\n$st');
      throw const NetworkFailure('Failed to communicate with AI');
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});
