import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/chat/domain/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('creates user message', () {
      final msg = ChatMessage(
        content: 'Hello',
        isUser: true,
        timestamp: DateTime(2024, 1, 1),
      );
      expect(msg.content, 'Hello');
      expect(msg.isUser, isTrue);
    });

    test('creates assistant message', () {
      final msg = ChatMessage(
        content: 'Hi there',
        isUser: false,
        timestamp: DateTime(2024, 1, 1),
      );
      expect(msg.isUser, isFalse);
    });
  });
}
