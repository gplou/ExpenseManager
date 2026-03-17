import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/ai_rate_limiter.dart';
import '../domain/chat_message.dart';

class ChatRepository {
  static const String _function = 'chat-transactions';

  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
    required String locale,
  }) async {
    if (!AiRateLimiter.instance.tryConsume()) {
      throw RateLimitFailure(
        'Límite alcanzado: máximo ${AiRateLimiter.maxPerMinute} usos por minuto. Espera un momento.',
      );
    }

    try {
      final historyPayload = history.map((m) {
        return <String, String>{
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.content,
        };
      }).toList();

      final response = await Supabase.instance.client.functions.invoke(
        _function,
        body: {
          'message': message,
          'history': historyPayload,
          'locale': locale,
        },
      );

      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        final error = data?['error'] as String? ?? 'Error desconocido';
        throw Exception(error);
      }

      final data = response.data as Map<String, dynamic>;
      final reply = data['reply'] as String?;
      if (reply == null || reply.isEmpty) {
        throw Exception('No se recibio respuesta de la IA');
      }

      return reply;
    } catch (e, st) {
      debugPrint('ChatRepository error: $e\n$st');
      rethrow;
    }
  }
}
