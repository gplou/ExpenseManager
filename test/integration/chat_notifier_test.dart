import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:productivity_app/features/chat/data/chat_repository.dart';
import 'package:productivity_app/features/chat/domain/chat_message.dart';
import 'package:productivity_app/features/chat/presentation/providers/chat_provider.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockChatRepository extends Mock implements ChatRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

ProviderContainer _makeContainer(_MockChatRepository repo) {
  return ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockChatRepository mockRepo;

  setUp(() {
    mockRepo = _MockChatRepository();
  });

  group('ChatNotifier', () {
    test('initial state is an empty list', () {
      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      expect(container.read(chatMessagesProvider), isEmpty);
    });

    test('sendMessage appends user message immediately', () async {
      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            history: any(named: 'history'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => 'OK');

      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container
          .read(chatMessagesProvider.notifier)
          .sendMessage('Hola', 'es');

      final messages = container.read(chatMessagesProvider);
      expect(messages.first.content, 'Hola');
      expect(messages.first.isUser, isTrue);
    });

    test('sendMessage appends AI reply after user message', () async {
      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            history: any(named: 'history'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => 'Respuesta IA');

      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container
          .read(chatMessagesProvider.notifier)
          .sendMessage('Hola', 'es');

      final messages = container.read(chatMessagesProvider);
      expect(messages.length, 2);
      expect(messages[1].content, 'Respuesta IA');
      expect(messages[1].isUser, isFalse);
    });

    test('sendMessage passes correct message and locale to repository',
        () async {
      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            history: any(named: 'history'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => 'OK');

      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container
          .read(chatMessagesProvider.notifier)
          .sendMessage('¿Cuánto gasté?', 'es');

      verify(() => mockRepo.sendMessage(
            message: '¿Cuánto gasté?',
            history: any(named: 'history'),
            locale: 'es',
          )).called(1);
    });

    test('sendMessage on error appends error message', () async {
      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            history: any(named: 'history'),
            locale: any(named: 'locale'),
          )).thenThrow(Exception('Network failure'));

      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container
          .read(chatMessagesProvider.notifier)
          .sendMessage('test', 'en');

      final messages = container.read(chatMessagesProvider);
      expect(messages.length, 2);
      expect(messages[1].isUser, isFalse);
      expect(messages[1].content, contains('Network failure'));
    });

    test('error message strips "Exception: " prefix', () async {
      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            history: any(named: 'history'),
            locale: any(named: 'locale'),
          )).thenThrow(Exception('Límite alcanzado'));

      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container
          .read(chatMessagesProvider.notifier)
          .sendMessage('test', 'en');

      final messages = container.read(chatMessagesProvider);
      final errorContent = messages.last.content;
      expect(errorContent, 'Error: Límite alcanzado');
    });

    test('chatLoadingProvider is false after a completed request', () async {
      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            history: any(named: 'history'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => 'OK');

      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      // Keep a listener so autoDispose providers stay alive
      container.listen(chatMessagesProvider, (_, __) {});
      container.listen(chatLoadingProvider, (_, __) {});

      await container
          .read(chatMessagesProvider.notifier)
          .sendMessage('hello', 'en');

      expect(container.read(chatLoadingProvider), isFalse);
    });

    test('multiple messages accumulate in order', () async {
      var callCount = 0;
      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            history: any(named: 'history'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => 'Reply ${++callCount}');

      final container = _makeContainer(mockRepo);
      addTearDown(container.dispose);

      await container
          .read(chatMessagesProvider.notifier)
          .sendMessage('Msg 1', 'en');
      await container
          .read(chatMessagesProvider.notifier)
          .sendMessage('Msg 2', 'en');

      final messages = container.read(chatMessagesProvider);
      expect(messages.length, 4);
      expect(messages[0].content, 'Msg 1');
      expect(messages[1].content, 'Reply 1');
      expect(messages[2].content, 'Msg 2');
      expect(messages[3].content, 'Reply 2');
    });
  });
}
