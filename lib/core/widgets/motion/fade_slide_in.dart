import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// Entrada suave (fundido + desplazamiento corto hacia arriba) al montarse.
///
/// [index] escalona varias entradas seguidas (listas, filas de un panel): el
/// retardo se codifica como un [Interval] dentro de un único controlador, sin
/// Timers sueltos que puedan quedar colgando si el widget se desmonta antes.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
    this.duration = MotionTokens.entrance,
    this.stagger = MotionTokens.stagger,
    this.maxStaggeredItems = 8,
  });

  final Widget child;
  final int index;

  /// Desplazamiento vertical inicial en px lógicos.
  final double offset;
  final Duration duration;
  final Duration stagger;

  /// A partir de este índice ya no se añade más retardo: en listas largas los
  /// últimos elementos no deberían tardar un segundo en aparecer.
  final int maxStaggeredItems;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final Duration _delay =
      widget.stagger * widget.index.clamp(0, widget.maxStaggeredItems);
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _delay + widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _ctrl,
    curve: Interval(
      _delay.inMicroseconds / (_delay + widget.duration).inMicroseconds,
      1,
      curve: MotionTokens.emphasized,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl.isAnimating || _ctrl.isCompleted) return;
    if (MotionTokens.reduced(context)) {
      _ctrl.value = 1;
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
