import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// Barra de progreso fina que se rellena desde 0 al aparecer y se desliza
/// (valor y color) cuando cambia — p. ej. al añadir un gasto que empuja un
/// presupuesto del 70% al 85%, la barra avanza y vira a ámbar en lugar de
/// saltar.
///
/// Por debajo sigue siendo un [LinearProgressIndicator] determinado: misma
/// semántica de accesibilidad y mismo aspecto que antes.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.duration = MotionTokens.fill,
  });

  /// 0..1 (se recorta).
  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;
  final BorderRadius borderRadius;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final reduced = MotionTokens.reduced(context);

    return ClipRRect(
      borderRadius: borderRadius,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: reduced ? Duration.zero : duration,
        curve: MotionTokens.emphasized,
        builder: (context, animatedColor, _) => TweenAnimationBuilder<double>(
          // begin solo se usa en el primer build: relleno desde 0 al montar.
          tween: Tween(begin: reduced ? target : 0, end: target),
          duration: reduced ? Duration.zero : duration,
          curve: MotionTokens.emphasized,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: minHeight,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(animatedColor ?? color),
          ),
        ),
      ),
    );
  }
}
