import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// Destello puntual sobre un elemento para señalar "esto acaba de cambiar":
/// un pequeño "pop" de escala y un halo de [color] que se desvanece.
///
/// Se dispara cada vez que [trigger] cambia (nunca en el primer build, salvo
/// [playOnMount]). [delayIndex] escalona varios destellos seguidos — p. ej.
/// los campos que la IA rellena uno detrás de otro tras una captura de voz.
class HighlightPulse extends StatefulWidget {
  const HighlightPulse({
    super.key,
    required this.trigger,
    required this.child,
    required this.color,
    this.delayIndex = 0,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.scale = 1.05,
    this.playOnMount = false,
  });

  /// Cualquier valor; cada cambio reproduce el destello.
  final Object? trigger;
  final Widget child;
  final Color color;
  final int delayIndex;
  final BorderRadius borderRadius;

  /// Escala máxima del "pop".
  final double scale;
  final bool playOnMount;

  @override
  State<HighlightPulse> createState() => _HighlightPulseState();
}

class _HighlightPulseState extends State<HighlightPulse>
    with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 90);

  late final AnimationController _ctrl = AnimationController(vsync: this);
  late Animation<double> _t = const AlwaysStoppedAnimation(0);
  bool _pendingMountPlay = false;

  @override
  void initState() {
    super.initState();
    _pendingMountPlay = widget.playOnMount;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pendingMountPlay) {
      _pendingMountPlay = false;
      _play();
    }
  }

  @override
  void didUpdateWidget(HighlightPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _play();
  }

  void _play() {
    if (MotionTokens.reduced(context)) return;
    final delay = _step * widget.delayIndex.clamp(0, 6);
    final total = delay + MotionTokens.highlight;
    _ctrl.duration = total;
    _t = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1),
    );
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _t.value;
        // Sube rápido (primer 25%) y se apaga despacio. En reposo (t = 0 ó 1)
        // glow = 0: el árbol se mantiene idéntico para no remontar al hijo.
        final glow = (t <= 0 || t >= 1)
            ? 0.0
            : (t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75);
        final pop = Curves.easeOut.transform(glow);
        return Transform.scale(
          scale: 1 + (widget.scale - 1) * pop,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: widget.color.withValues(alpha: 0.9 * glow),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35 * glow),
                  blurRadius: 14 * glow,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
