import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/chat_repository.dart';
import '../../domain/chat_message.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

final chatMessagesProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, List<ChatMessage>>(
  (ref) => ChatNotifier(ref.read(chatRepositoryProvider)),
);

final chatLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier(this._repository) : super(const []);

  final ChatRepository _repository;

  Future<void> sendMessage(String text, String locale, WidgetRef ref) async {
    final userMsg = ChatMessage(
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];
    ref.read(chatLoadingProvider.notifier).state = true;

    try {
      final reply = await _repository.sendMessage(
        message: text,
        history: state,
        locale: locale,
      );

      final aiMsg = ChatMessage(
        content: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = [...state, aiMsg];
    } catch (e) {
      final errorMsg = ChatMessage(
        content: 'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = [...state, errorMsg];
    } finally {
      ref.read(chatLoadingProvider.notifier).state = false;
    }
  }
}
