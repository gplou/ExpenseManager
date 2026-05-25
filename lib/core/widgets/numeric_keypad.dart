import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Operadores aritméticos soportados por el keypad.
enum _Op { add, sub }

/// Estado controlador del importe para [NumericKeypad].
///
/// Maneja la lógica de display + operación pendiente. Expón `value` como el
/// resultado numérico final (resolvedo cuando el usuario pulsa "=" u "OK").
class AmountKeypadController extends ChangeNotifier {
  AmountKeypadController({String initial = ''})
      : _current = initial,
        _previous = null,
        _pendingOp = null;

  String _current;
  double? _previous;
  _Op? _pendingOp;

  /// Texto del operando que se está editando.
  String get current => _current;

  /// Texto del operando previo (si hay op pendiente).
  String? get previousText {
    if (_previous == null) return null;
    return _formatDouble(_previous!);
  }

  /// Operador pendiente como símbolo.
  String? get pendingOpSymbol {
    return switch (_pendingOp) {
      _Op.add => '+',
      _Op.sub => '−',
      null => null,
    };
  }

  /// Resuelve la operación pendiente (si la hay) y devuelve el valor final.
  /// Si la entrada es inválida, devuelve null.
  double? resolve() {
    final cur = double.tryParse(_current.replaceAll(',', '.'));
    if (cur == null) {
      // Si no hay operando actual pero sí previo, devolver previo.
      return _previous;
    }
    if (_previous == null || _pendingOp == null) return cur;
    switch (_pendingOp!) {
      case _Op.add:
        return _previous! + cur;
      case _Op.sub:
        return _previous! - cur;
    }
  }

  /// Pulsación de dígito.
  void pressDigit(String digit) {
    if (_current == '0') {
      _current = digit;
    } else {
      _current = '$_current$digit';
    }
    notifyListeners();
  }

  /// Punto/coma decimal — solo si no hay ya separador.
  void pressDecimal(String separator) {
    if (_current.isEmpty) {
      _current = '0$separator';
      notifyListeners();
      return;
    }
    if (_current.contains('.') || _current.contains(',')) return;
    _current = '$_current$separator';
    notifyListeners();
  }

  /// Backspace: borra último char del operando actual.
  void backspace() {
    if (_current.isNotEmpty) {
      _current = _current.substring(0, _current.length - 1);
      notifyListeners();
      return;
    }
    // Si el operando actual está vacío y hay op pendiente → cancelar la op.
    if (_pendingOp != null) {
      _pendingOp = null;
      _current = _previous != null ? _formatDouble(_previous!) : '';
      _previous = null;
      notifyListeners();
    }
  }

  /// Aplica suma. Si ya hay op pendiente, resuelve y encadena.
  void pressAdd() => _applyOp(_Op.add);

  /// Aplica resta. Si ya hay op pendiente, resuelve y encadena.
  void pressSubtract() => _applyOp(_Op.sub);

  void _applyOp(_Op op) {
    final cur = double.tryParse(_current.replaceAll(',', '.'));
    if (cur == null && _previous == null) return;
    if (_previous != null && _pendingOp != null && cur != null) {
      // Cadena: resolver y usar como nuevo previous.
      final resolved = switch (_pendingOp!) {
        _Op.add => _previous! + cur,
        _Op.sub => _previous! - cur,
      };
      _previous = resolved;
    } else if (cur != null) {
      _previous = cur;
    }
    _pendingOp = op;
    _current = '';
    notifyListeners();
  }

  /// Resuelve la operación pendiente y deja el resultado como display.
  void pressEquals() {
    final r = resolve();
    if (r == null) return;
    _current = _formatDouble(r);
    _previous = null;
    _pendingOp = null;
    notifyListeners();
  }

  /// Sustituye el valor completo con un double dado.
  void setValue(double value) {
    _current = _formatDouble(value);
    _previous = null;
    _pendingOp = null;
    notifyListeners();
  }

  /// Resetea a vacío.
  void clear() {
    _current = '';
    _previous = null;
    _pendingOp = null;
    notifyListeners();
  }

  static final RegExp _trailingZeros = RegExp(r'0+$');
  static final RegExp _trailingSeparator = RegExp(r'[\.,]$');

  static String _formatDouble(double v) {
    // Sin decimales si es entero, máximo 2 si no.
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v
        .toStringAsFixed(2)
        .replaceAll(_trailingZeros, '')
        .replaceAll(_trailingSeparator, '');
  }
}

/// Keypad numérico custom, embebible en pantalla, con + / − y OK propio.
///
/// Ejemplo:
/// ```dart
/// final ctrl = AmountKeypadController();
/// ...
/// NumericKeypad(
///   controller: ctrl,
///   accent: AppColors.mutedTerra,
///   onSubmit: () { final v = ctrl.resolve(); save(v!); },
/// )
/// ```
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.accent,
    this.decimalSeparator,
    this.submitLabel,
    this.canSubmit = true,
    this.fillVertical = false,
  });

  final AmountKeypadController controller;
  final VoidCallback onSubmit;
  final Color? accent;

  /// Si es null, se resuelve desde el locale actual.
  final String? decimalSeparator;
  final String? submitLabel;
  final bool canSubmit;

  /// When true, the keypad expands rows/keys to fill all available vertical
  /// space. Use inside an `Expanded` so the parent provides bounded height.
  final bool fillVertical;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? AppColors.dustyTeal;
    final locale = Localizations.localeOf(context).toString();
    final separator = decimalSeparator ??
        NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize:
                fillVertical ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // Fila 1: 7 8 9 ⌫
              _row([
                _digit('7'),
                _digit('8'),
                _digit('9'),
                _action(
                  icon: Icons.backspace_outlined,
                  semanticLabel: 'Backspace',
                  onTap: controller.backspace,
                  onLongPress: controller.clear,
                ),
              ]),
              // Fila 2: 4 5 6 +
              _row([
                _digit('4'),
                _digit('5'),
                _digit('6'),
                _opKey('+', _Op.add, effectiveAccent),
              ]),
              // Fila 3: 1 2 3 −
              _row([
                _digit('1'),
                _digit('2'),
                _digit('3'),
                _opKey('−', _Op.sub, effectiveAccent),
              ]),
              // Fila 4: separator 0 = OK
              _row([
                _decimal(separator),
                _digit('0'),
                _equalsKey(effectiveAccent),
                _submitKey(effectiveAccent),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _row(List<Widget> children) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: children
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: c,
                  ),
                ))
            .toList(),
      ),
    );
    return fillVertical ? Expanded(child: row) : row;
  }

  Widget _digit(String d) => _KeypadKey(
        label: d,
        fill: fillVertical,
        onTap: () => controller.pressDigit(d),
      );

  Widget _decimal(String separator) => _KeypadKey(
        label: separator,
        fill: fillVertical,
        onTap: () => controller.pressDecimal(separator),
      );

  Widget _action({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return _KeypadKey(
      icon: icon,
      semanticLabel: semanticLabel,
      fill: fillVertical,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _opKey(String symbol, _Op op, Color accent) {
    return _KeypadKey(
      label: symbol,
      foreground: accent,
      fill: fillVertical,
      onTap: () => switch (op) {
        _Op.add => controller.pressAdd(),
        _Op.sub => controller.pressSubtract(),
      },
    );
  }

  Widget _equalsKey(Color accent) {
    return _KeypadKey(
      label: '=',
      foreground: accent,
      fill: fillVertical,
      onTap: controller.pressEquals,
    );
  }

  Widget _submitKey(Color accent) {
    return _KeypadKey(
      label: submitLabel ?? 'OK',
      icon: Icons.check_rounded,
      filled: true,
      fill: fillVertical,
      backgroundColor: accent,
      foreground: AppColors.pureWhite,
      enabled: canSubmit,
      onTap: () {
        // Si hay op pendiente, resolverla antes de submit.
        if (controller.pendingOpSymbol != null) {
          controller.pressEquals();
        }
        onSubmit();
      },
    );
  }
}

class _KeypadKey extends StatefulWidget {
  const _KeypadKey({
    this.label,
    this.icon,
    this.semanticLabel,
    required this.onTap,
    this.onLongPress,
    this.foreground,
    this.backgroundColor,
    this.filled = false,
    this.enabled = true,
    this.fill = false,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? foreground;
  final Color? backgroundColor;
  final bool filled;
  final bool enabled;

  /// When true, the key grows to fill the parent's vertical constraint
  /// instead of using its default 56 px height.
  final bool fill;

  @override
  State<_KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<_KeypadKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final bg = widget.filled
        ? (widget.backgroundColor ?? AppColors.dustyTeal)
        : (isDark ? AppColors.darkSurfaceHigh : AppColors.surfaceElevated);
    final fg = widget.foreground ??
        (widget.filled ? AppColors.pureWhite : cs.onSurface);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: widget.enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onTap();
              }
            : null,
        onLongPress: widget.onLongPress != null && widget.enabled
            ? () {
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              }
            : null,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: widget.fill ? double.infinity : 56,
          decoration: BoxDecoration(
            color: _pressed ? bg.withValues(alpha: 0.75) : bg,
            borderRadius: AppRadius.radiusLg,
          ),
          alignment: Alignment.center,
          child: widget.icon != null
              ? Icon(widget.icon, color: fg, size: 22)
              : Text(
                  widget.label!,
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 18,
                    fontWeight:
                        widget.filled ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.3,
                    color: widget.enabled ? fg : fg.withValues(alpha: 0.4),
                  ),
                ),
        ),
      ),
    );
  }
}
