class ChatMessage {
  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  final String content;
  final bool isUser;
  final DateTime timestamp;
}
