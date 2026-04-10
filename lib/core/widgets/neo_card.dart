import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Tarjeta "Calm Card": fondo blanco, sombra difusa suave, sin borde duro.
/// El accentColor se usa como pequeño indicador visual (borde superior o glow).
class NeoCard extends StatelessWidget {
  const NeoCard({
    super.key,
    required this.child,
    this.accentColor = AppColors.dustyTeal,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.shadowOffset = const Offset(0, 4),
    this.onTap,
  });

  final Widget child;
  final Color accentColor;
  final EdgeInsets padding;
  final double borderRadius;
  final Offset shadowOffset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark ? cs.outline : AppColors.borderLight,
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Botón primario con efecto "press" suave (escala leve al pulsar).
class NeoBrutalButton extends StatefulWidget {
  const NeoBrutalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.backgroundColor = AppColors.dustyTeal,
    this.foregroundColor = AppColors.pureWhite,
    this.width = double.infinity,
    this.height = 56.0,
    this.isLoading = false,
    this.disabled = false,
    this.emoji,
  });

  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final double width;
  final double height;
  final bool isLoading;
  final bool disabled;
  final String? emoji;

  @override
  State<NeoBrutalButton> createState() => _NeoBrutalButtonState();
}

class _NeoBrutalButtonState extends State<NeoBrutalButton> {
  bool _pressed = false;

  void _onTapDown(_) => setState(() => _pressed = true);

  void _onTapUp(_) {
    setState(() => _pressed = false);
    if (!widget.disabled && !widget.isLoading) widget.onTap?.call();
  }

  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final isActive = !widget.disabled && !widget.isLoading;
    final bg = widget.disabled ? AppColors.surfaceElevated : widget.backgroundColor;
    final fg = widget.disabled ? AppColors.textSubtle : widget.foregroundColor;

    return GestureDetector(
      onTapDown: isActive ? _onTapDown : null,
      onTapUp: isActive ? _onTapUp : null,
      onTapCancel: isActive ? _onTapCancel : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.width,
        height: widget.height,
        transform: (_pressed && isActive)
            ? (Matrix4.diagonal3Values(0.97, 0.97, 1.0))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: (_pressed || widget.disabled)
              ? []
              : [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: widget.isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.emoji != null) ...[
                      Text(widget.emoji!, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// FAB circular con efecto spring al pulsar.
class NeoFab extends StatefulWidget {
  const NeoFab({
    super.key,
    required this.onTap,
    this.icon = Icons.add,
    this.accentColor = AppColors.dustyTeal,
    this.size = 64.0,
    this.heroTag,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color accentColor;
  final double size;
  final Object? heroTag;

  @override
  State<NeoFab> createState() => _NeoFabState();
}

class _NeoFabState extends State<NeoFab> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.accentColor,
            shape: BoxShape.circle,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Icon(
            widget.icon,
            color: AppColors.pureWhite,
            size: 28,
          ),
        ),
      ),
    );
  }
}
