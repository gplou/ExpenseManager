import 'package:flutter/material.dart';

import 'motion_tokens.dart';
import 'route_cover_scope.dart';

/// Barra de progreso fina que se rellena desde 0 al aparecer y se desliza
/// (valor y color) cuando cambia — p. ej. al añadir un gasto que empuja un
/// presupuesto del 70% al 85%, la barra avanza y vira a ámbar en lugar de
/// saltar.
///
/// Por debajo sigue siendo un [LinearProgressIndicator] determinado: misma
/// semántica de accesibilidad y mismo aspecto que antes.
class AnimatedProgressBar extends StatefulWidget {
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
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar> {
  /// Lo que la barra enseña ahora mismo. Mientras la ruta está tapada (p. ej.
  /// la hoja de "nueva transacción" encima del dashboard) se congela aquí, y
  /// el avance/cambio de color se anima al destaparse, cuando se ve.
  double? _shownValue;
  Color? _shownColor;

  @override
  Widget build(BuildContext context) {
    final target = widget.value.clamp(0.0, 1.0);
    final reduced = MotionTokens.reduced(context);
    final covered = RouteCoverScope.isCovered(context);

    if (reduced || !covered) {
      _shownValue = target;
      _shownColor = widget.color;
    } else {
      // Montada ya tapada: se queda vacía y se rellena al destaparse.
      _shownValue ??= 0;
      _shownColor ??= widget.color;
    }
    final value = _shownValue!;
    final color = _shownColor!;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: reduced ? Duration.zero : widget.duration,
        curve: MotionTokens.emphasized,
        builder: (context, animatedColor, _) => TweenAnimationBuilder<double>(
          // begin solo se usa en el primer build: relleno desde 0 al montar.
          tween: Tween(begin: reduced ? value : 0, end: value),
          duration: reduced ? Duration.zero : widget.duration,
          curve: MotionTokens.emphasized,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: widget.minHeight,
            backgroundColor: widget.backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(animatedColor ?? color),
          ),
        ),
      ),
    );
  }
}
