import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/core/utils/ai_rate_limiter.dart';
import 'package:expense_manager/features/chat/domain/chat_message.dart';

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

      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        final error = data?['error'] as String? ?? 'Unknown error';
        throw ServerFailure(error);
      }

      final data = response.data as Map<String, dynamic>;
      final reply = data['reply'] as String?;
      if (reply == null || reply.isEmpty) {
        throw const ServerFailure('No response received from AI');
      }

      return reply;
    } on FunctionException catch (e, st) {
      debugPrint('ChatRepository FunctionException: status=${e.status} details=${e.details}\n$st');
      final details = e.details;
      String? serverMsg;
      if (details is Map) {
        serverMsg = details['error'] as String?;
      }
      final msg = serverMsg ?? 'Server error (${e.status ?? 'unknown'})';
      if (e.status == 429) throw RateLimitFailure(msg);
      throw ServerFailure(msg);
    } on AppFailure {
      rethrow;
    } catch (e, st) {
      debugPrint('ChatRepository error: $e\n$st');
      throw const NetworkFailure('Failed to communicate with AI');
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});
