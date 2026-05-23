import 'package:flutter/material.dart';

/// Escala de elevación Quiet Wealth.
///
/// Sombras de "humo": tinte ink (`#0B0F0C`) muy diluido en vez de negro puro.
/// Difusión amplia y desplazamiento bajo — sensación de papel flotando, no de
/// elemento que pesa. `e1`–`e3` jerarquía progresiva; `tinted` para acentos.
class AppElevation {
  AppElevation._();

  /// Sin sombra.
  static const List<BoxShadow> e0 = <BoxShadow>[];

  /// Reposo: tarjeta apenas separada del fondo.
  static const List<BoxShadow> e1 = [
    BoxShadow(
      color: Color(0x0A0B0F0C), // ink @ 4%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Hover/focus, hero cards y tarjetas elevadas.
  static const List<BoxShadow> e2 = [
    BoxShadow(
      color: Color(0x140B0F0C), // ink @ 8%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x080B0F0C), // halo cercano
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Diálogos, bottom sheets, popovers.
  static const List<BoxShadow> e3 = [
    BoxShadow(
      color: Color(0x1F0B0F0C), // ink @ 12%
      blurRadius: 64,
      offset: Offset(0, 24),
    ),
    BoxShadow(
      color: Color(0x0F0B0F0C),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Glow de color para CTAs primarios. Halo amplio y de baja opacidad —
  /// presencia sin neón.
  static List<BoxShadow> tinted(Color color, {double opacity = 0.18}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
