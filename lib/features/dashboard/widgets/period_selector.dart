import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';

/// Chip de período (Hoy / Semana / Mes / Año). Quieto, sin color de marca:
/// selected = surface elevada con hairline, idle = transparente.
class PeriodChip extends StatelessWidget {
  const PeriodChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final Color bg;
    final Color borderColor;
    final Color textColor;
    final FontWeight weight;

    if (isSelected) {
      bg = cs.surface;
      borderColor = isDark ? AppColors.dividerDark : AppColors.divider;
      textColor = cs.onSurface;
      weight = FontWeight.w600;
    } else {
      bg = Colors.transparent;
      borderColor = Colors.transparent;
      textColor = isDark ? AppColors.graphiteDark : AppColors.graphite;
      weight = FontWeight.w500;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isSelected ? AppElevation.e1 : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 13,
            fontWeight: weight,
            color: textColor,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

/// Chip-icono para el rango personalizado (calendario). Mismo lenguaje que
/// [PeriodChip], pero el estado activo usa el acento `warning` (amber apagado)
/// para diferenciar visualmente que es un rango ad-hoc.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bg;
    final Color iconColor;
    if (isActive) {
      bg = AppColors.warningSoft;
      iconColor = AppColors.warning;
    } else {
      bg = Colors.transparent;
      iconColor = isDark ? AppColors.graphiteDark : AppColors.graphite;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}
