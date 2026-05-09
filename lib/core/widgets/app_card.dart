import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_spacing.dart';

/// Variantes de tarjeta unificadas.
///
/// - [outlined]: borde 1.5px sin sombra (default).
/// - [filled]: superficie acentuada (typically `accentLight`) con borde tinted.
/// - [elevated]: sombra `e1` para reposo o `e2` cuando `selected` es true.
enum AppCardVariant { outlined, filled, elevated }

/// Tarjeta única que sustituye `NeoCard`, `_CompactCard` y los Container
/// con `softShadow*` repartidos por las screens.
///
/// API mínima: `variant`, `accent`, `padding`, `onTap`. Maneja:
/// - dark/light mode automáticamente.
/// - haptic feedback en tap (si `onTap` provisto).
/// - tap targets >= 48 px lógicos.
/// - estado disabled (gris atenuado).
/// - estado selected (accent border + accent label).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.outlined,
    this.accent,
    this.accentLight,
    this.padding = AppSpacing.paddingLg,
    this.onTap,
    this.selected = false,
    this.disabled = false,
    this.borderRadius,
    this.semanticLabel,
    this.semanticButton = false,
  });

  final Widget child;
  final AppCardVariant variant;

  /// Color de acento para borde activo / texto / selected state.
  final Color? accent;

  /// Tinte sutil del fondo cuando `selected` o variant=filled.
  final Color? accentLight;

  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final bool disabled;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final bool semanticButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? AppRadius.radiusLg;

    final effectiveAccent = accent ?? AppColors.dustyTeal;
    final effectiveAccentLight = accentLight ??
        (isDark
            ? effectiveAccent.withValues(alpha: 0.15)
            : effectiveAccent.withValues(alpha: 0.08));

    final Color bg;
    final Color borderColor;
    final List<BoxShadow> shadow;
    final double borderWidth;

    if (disabled) {
      bg = cs.onSurface.withValues(alpha: 0.04);
      borderColor = cs.onSurface.withValues(alpha: 0.08);
      shadow = AppElevation.e0;
      borderWidth = 1.5;
    } else {
      switch (variant) {
        case AppCardVariant.outlined:
          bg = selected ? effectiveAccentLight : cs.surface;
          borderColor = selected
              ? effectiveAccent
              : (isDark ? AppColors.darkBorderColor : AppColors.borderLight);
          shadow = selected ? AppElevation.e0 : AppElevation.e1;
          borderWidth = 1.5;
        case AppCardVariant.filled:
          bg = effectiveAccentLight;
          borderColor = effectiveAccent.withValues(alpha: isDark ? 0.5 : 0.25);
          shadow = AppElevation.e0;
          borderWidth = 1;
        case AppCardVariant.elevated:
          bg = cs.surface;
          borderColor = isDark
              ? AppColors.darkBorderColor
              : AppColors.borderLight;
          shadow = selected ? AppElevation.e2 : AppElevation.e1;
          borderWidth = 1;
      }
    }

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: radius,
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap != null && !disabled) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap!();
          },
          borderRadius: radius,
          splashColor: effectiveAccent.withValues(alpha: 0.08),
          highlightColor: effectiveAccent.withValues(alpha: 0.04),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTapTargets.minSize),
            child: content,
          ),
        ),
      );
    }

    if (semanticLabel != null || semanticButton) {
      content = Semantics(
        label: semanticLabel,
        button: semanticButton,
        enabled: !disabled,
        selected: selected,
        child: content,
      );
    }

    return content;
  }
}

/// Versión compacta para filas tipo "categoría / subcategoría" en formularios.
/// Mantiene la API mínima: emoji o icon + label + chevron, todo con accent.
class AppCompactRow extends StatelessWidget {
  const AppCompactRow({
    super.key,
    required this.label,
    required this.hasValue,
    required this.onTap,
    this.emoji,
    this.icon,
    this.accent,
    this.accentLight,
    this.disabled = false,
    this.semanticLabel,
  });

  final String? emoji;
  final IconData? icon;
  final String label;
  final bool hasValue;
  final VoidCallback? onTap;
  final Color? accent;
  final Color? accentLight;
  final bool disabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accent ?? AppColors.dustyTeal;
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      accent: effectiveAccent,
      accentLight: accentLight,
      selected: hasValue,
      disabled: disabled,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: disabled ? null : onTap,
      semanticLabel: semanticLabel ?? label,
      semanticButton: true,
      child: Row(
        children: [
          if (emoji != null) ...[
            Opacity(
              opacity: disabled ? 0.3 : 1.0,
              child: Text(emoji!, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ] else if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: disabled
                  ? cs.onSurface.withValues(alpha: 0.3)
                  : hasValue
                      ? effectiveAccent
                      : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: disabled
                    ? cs.onSurface.withValues(alpha: 0.4)
                    : hasValue
                        ? effectiveAccent
                        : AppColors.textMuted,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: disabled
                ? cs.onSurface.withValues(alpha: 0.3)
                : hasValue
                    ? effectiveAccent
                    : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
