import 'package:clock/clock.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:expense_manager/features/chat/data/chat_repository.dart';
import 'package:expense_manager/features/chat/domain/chat_message.dart';

final chatMessagesProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, List<ChatMessage>>(
  (ref) => ChatNotifier(
    ref.read(chatRepositoryProvider),
    onLoadingChanged: (v) => ref.read(chatLoadingProvider.notifier).state = v,
  ),
);

final chatLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier(
    this._repository, {
    required void Function(bool) onLoadingChanged,
  })  : _onLoadingChanged = onLoadingChanged,
        super(const []);

  final ChatRepository _repository;
  final void Function(bool) _onLoadingChanged;

  Future<void> sendMessage(String text, String locale) async {
    final userMsg = ChatMessage(
      content: text,
      isUser: true,
      timestamp: clock.now(),
    );
    state = [...state, userMsg];
    _onLoadingChanged(true);

    try {
      final reply = await _repository.sendMessage(
        message: text,
        history: state,
        locale: locale,
      );

      final aiMsg = ChatMessage(
        content: reply,
        isUser: false,
        timestamp: clock.now(),
      );
      state = [...state, aiMsg];
    } catch (e) {
      final errorMsg = ChatMessage(
        content: 'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        isUser: false,
        timestamp: clock.now(),
      );
      state = [...state, errorMsg];
    } finally {
      _onLoadingChanged(false);
    }
  }
}
