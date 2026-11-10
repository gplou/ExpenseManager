import 'package:flutter/material.dart';

/// Texto numérico que interpola entre el valor anterior y el nuevo cuando
/// cambia. Útil para balance / income / expense después de guardar una
/// transacción — el cambio se siente "vivo" en lugar de saltar.
///
/// - [countUpOnMount]: al aparecer cuenta desde 0 hasta el valor (entrada del
///   dashboard). Por defecto no, para no animar cifras secundarias.
/// - [pulseOnChange]: cuando el valor cambia después del primer build, la
///   cifra hace un pequeño "pop" de escala mientras cuenta, para que se note
///   que la transacción recién guardada se ha sumado al total.
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.countUpOnMount = false,
    this.pulseOnChange = false,
    this.pulseScope,
  });

  final double value;
  final String Function(double v) formatter;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final bool countUpOnMount;
  final bool pulseOnChange;

  /// Contexto del dato (p. ej. el periodo mostrado). Si cambia junto con el
  /// valor, la cifra cuenta hasta el nuevo valor pero sin "pop": cambiar de
  /// Semana a Mes no es "se ha sumado algo", es otro dato.
  final Object? pulseScope;

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount> {
  late double _previous = widget.countUpOnMount ? 0 : widget.value;

  /// Se incrementa en cada cambio real de valor; reinicia el "pop".
  int _changeCount = 0;

  @override
  void didUpdateWidget(AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previous = oldWidget.value;
      if (oldWidget.pulseScope == widget.pulseScope) _changeCount++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations || _previous == widget.value) {
      return Text(widget.formatter(widget.value), style: widget.style);
    }
    final counter = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _previous, end: widget.value),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, v, _) =>
          Text(widget.formatter(v), style: widget.style),
    );
    if (!widget.pulseOnChange || _changeCount == 0) return counter;
    return TweenAnimationBuilder<double>(
      // Clave nueva por cambio → la animación de 0 a 1 vuelve a empezar.
      key: ValueKey(_changeCount),
      tween: Tween(begin: 0, end: 1),
      duration: widget.duration,
      builder: (context, t, child) => Transform.scale(
        // Sube a 1.03 en el primer tercio y vuelve a 1.0: se nota sin
        // descolocar la cifra.
        scale: 1 + 0.03 * (t < 0.33 ? t / 0.33 : (1 - t) / 0.67),
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: counter,
    );
  }
}
