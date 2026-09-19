import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/extensions.dart';

/// Chip de selección — usable como segmento (varios en fila, uno activo) o
/// como toggle (uno solo, on/off). Transparente por defecto, borde 1px;
/// seleccionado con borde de acento + fondo tintado, leyendo la paleta del
/// [ChipThemeData] activo para no duplicar tokens.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final chipTheme = Theme.of(context).chipTheme;
    final accent = context.colors.primary;
    final selectedBg = chipTheme.selectedColor ?? accent;
    final selectedFg = chipTheme.secondaryLabelStyle?.color ?? accent;
    final idleFg = chipTheme.labelStyle?.color ?? context.appColors.text;
    final idleBorder = chipTheme.side?.color ?? context.appColors.divider;
    final foreground = selected ? selectedFg : idleFg;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: chipTheme.padding ??
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : idleBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: (selected
                        ? chipTheme.secondaryLabelStyle
                        : chipTheme.labelStyle)
                    ?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
