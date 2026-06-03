import 'package:flutter/material.dart';

import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/features/chat/domain/chat_message.dart';

/// Burbuja editorial: usuario en ink azul, asistente en superficie con
/// hairline. Esquinas asimétricas marcan el origen.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final cs = Theme.of(context).colorScheme;

    final Color bgColor;
    final Color textColor;
    final Color? borderColor;

    if (isUser) {
      bgColor = cs.primary;
      textColor = cs.onPrimary;
      borderColor = null;
    } else {
      bgColor = context.appColors.raised;
      textColor = context.appColors.text;
      borderColor = context.appColors.divider;
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
          bottom: 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
            bottomRight: Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
          ),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : null,
        ),
        child: Text(
          message.content,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textColor,
            height: 1.5,
            letterSpacing: -0.05,
          ),
        ),
      ),
    );
  }
}
