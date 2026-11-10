import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// Hunde ligeramente a su hijo mientras se pulsa y lo suelta con un pequeño
/// rebote, como un botón físico.
///
/// Usa un [Listener] (no un GestureDetector), así que no compite con el
/// InkWell / GestureDetector del hijo: el toque sigue llegando al hijo tal
/// cual, esto solo añade la respuesta visual.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.92,
    this.enabled = true,
  });

  final Widget child;

  /// Escala mínima mientras el dedo está apoyado.
  final double pressedScale;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  // 0 = reposo, 1 = hundido. Los límites admiten negativos para que el
  // easeOutBack del rebote pueda pasarse de 1.0 de escala sin recortarse.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent _) {
    if (!widget.enabled || MotionTokens.reduced(context)) return;
    _ctrl.animateTo(1, duration: MotionTokens.press, curve: Curves.easeOut);
  }

  void _up([PointerEvent? _]) {
    if (_ctrl.value == 0) return;
    _ctrl.animateTo(
      0,
      duration: MotionTokens.release,
      curve: MotionTokens.spring,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.scale(
          scale: 1 - (1 - widget.pressedScale) * _ctrl.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
