import 'package:clock/clock.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:expense_manager/core/errors/failure_localizations.dart';
import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/features/chat/data/chat_repository.dart';
import 'package:expense_manager/features/chat/domain/chat_message.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

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

  Future<void> sendMessage(
    String text,
    String locale, {
    required AppLocalizations l10n,
  }) async {
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
    } on AppFailure catch (f) {
      // El repositorio siempre lanza AppFailure (nunca excepciones crudas) —
      // localizedMessage cubre el switch exhaustivo, sin fallback genérico.
      final errorMsg = ChatMessage(
        content: f.localizedMessage(l10n),
        isUser: false,
        timestamp: clock.now(),
      );
      state = [...state, errorMsg];
    } finally {
      _onLoadingChanged(false);
    }
  }
}
