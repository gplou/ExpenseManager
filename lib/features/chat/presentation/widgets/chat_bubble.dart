import 'package:flutter/material.dart';

import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/features/chat/domain/chat_message.dart';

/// Burbuja editorial: usuario en ink azul, asistente en superficie con
/// hairline. Esquinas asimétricas marcan el origen.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.animate = false});

  final ChatMessage message;

  /// Revela el texto palabra a palabra (respuesta recién llegada del
  /// asistente). La pantalla lo activa una sola vez por mensaje.
  final bool animate;

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
        child: RevealText(
          text: message.content,
          animate: animate,
          style: TextStyle(
            fontFamily: 'Inter',
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

/// Texto que aparece palabra a palabra, como si el asistente lo escribiera.
///
/// - El texto completo se maqueta desde el primer frame (lo aún no revelado va
///   transparente): la burbuja nace con su tamaño final, así que ni el layout
///   ni el scroll de la lista saltan mientras se escribe.
/// - La duración se adapta a la longitud (~14 ms por carácter) con un tope de
///   1,6 s: las respuestas largas no hacen esperar para poder leerlas.
/// - Tocar el texto lo muestra entero al instante.
/// - Con "reducir movimiento" se muestra directamente.
class RevealText extends StatefulWidget {
  const RevealText({
    super.key,
    required this.text,
    required this.style,
    this.animate = true,
  });

  final String text;
  final TextStyle style;
  final bool animate;

  static const _msPerChar = 14;
  static const _minDuration = Duration(milliseconds: 350);
  static const _maxDuration = Duration(milliseconds: 1600);

  @visibleForTesting
  static Duration durationFor(String text) {
    final ms = (text.length * _msPerChar)
        .clamp(_minDuration.inMilliseconds, _maxDuration.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  @override
  State<RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<RevealText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: RevealText.durationFor(widget.text),
    value: widget.animate ? 0 : 1,
  );

  /// Índices de fin de cada palabra (incluido su espacio posterior): se
  /// revela por palabras enteras, no por letras, que se lee mejor.
  late final List<int> _wordEnds = _computeWordEnds(widget.text);

  static List<int> _computeWordEnds(String text) {
    final ends = <int>[];
    for (final m in RegExp(r'\S+\s*').allMatches(text)) {
      ends.add(m.end);
    }
    return ends.isEmpty ? [text.length] : ends;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl.value < 1 && !_ctrl.isAnimating) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _ctrl.value = 1;
      } else {
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_ctrl.isAnimating) _ctrl.value = 1;
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          if (t >= 1) return Text(widget.text, style: widget.style);
          final words = (_wordEnds.length * t).ceil();
          final cut = words == 0 ? 0 : _wordEnds[words - 1];
          return Text.rich(
            TextSpan(
              style: widget.style,
              children: [
                TextSpan(text: widget.text.substring(0, cut)),
                TextSpan(
                  text: widget.text.substring(cut),
                  style: TextStyle(
                    color: (widget.style.color ?? const Color(0xFF000000))
                        .withValues(alpha: 0),
                  ),
                ),
              ],
            ),
            // Lectores de pantalla: el mensaje completo desde el principio.
            semanticsLabel: widget.text,
          );
        },
      ),
    );
  }
}
