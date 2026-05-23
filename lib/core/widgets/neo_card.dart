import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_spacing.dart';

/// "Calm Card": hairline 1px sobre la superficie, sin sombra dura.
/// El accentColor queda disponible para descendientes que decoren un detalle.
class NeoCard extends StatelessWidget {
  const NeoCard({
    super.key,
    required this.child,
    this.accentColor = AppColors.inkBlue,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadius.lg,
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
            color: isDark ? AppColors.dividerDark : AppColors.divider,
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Botón primario con micro-press (escala 0.97 + haptic light).
/// Sombra tinted muy sutil — presencia sin ruido.
class NeoBrutalButton extends StatefulWidget {
  const NeoBrutalButton({
    super.key,
    required this.label,
    required this.onTap,
    this.backgroundColor = AppColors.inkBlue,
    this.foregroundColor = AppColors.paper,
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

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);

  void _onTapUp(TapUpDetails _) {
    setState(() => _pressed = false);
    if (!widget.disabled && !widget.isLoading) {
      HapticFeedback.lightImpact();
      widget.onTap?.call();
    }
  }

  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final isActive = !widget.disabled && !widget.isLoading;
    final bg = widget.disabled ? AppColors.raised : widget.backgroundColor;
    final fg = widget.disabled ? AppColors.graphiteSoft : widget.foregroundColor;

    return GestureDetector(
      onTapDown: isActive ? _onTapDown : null,
      onTapUp: isActive ? _onTapUp : null,
      onTapCancel: isActive ? _onTapCancel : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: widget.width,
        height: widget.height,
        transform: (_pressed && isActive)
            ? Matrix4.diagonal3Values(0.98, 0.98, 1.0)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: (_pressed || widget.disabled)
              ? const []
              : AppElevation.tinted(bg, opacity: 0.20),
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
                        fontFamily: 'GeneralSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// FAB circular con micro-spring al pulsar. Halo tinted de baja opacidad.
class NeoFab extends StatefulWidget {
  const NeoFab({
    super.key,
    required this.onTap,
    this.icon = Icons.add,
    this.accentColor = AppColors.inkBlue,
    this.size = 60.0,
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
      duration: const Duration(milliseconds: 140),
    );
    _scale = Tween(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.lightImpact();
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
                : AppElevation.tinted(widget.accentColor, opacity: 0.24),
          ),
          child: Icon(
            widget.icon,
            color: AppColors.paper,
            size: 26,
          ),
        ),
      ),
    );
  }
}
