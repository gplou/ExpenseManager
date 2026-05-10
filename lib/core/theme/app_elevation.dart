import 'package:flutter/material.dart';

/// Escala de elevación (sombras) intencional.
///
/// `e0` plano, `e1`-`e3` jerarquía progresiva, `tinted` para glows con color
/// (acciones críticas tipo CTA con feedback de marca).
class AppElevation {
  AppElevation._();

  /// Sin sombra.
  static const List<BoxShadow> e0 = <BoxShadow>[];

  /// Reposo: tarjetas planas con presencia mínima.
  static const List<BoxShadow> e1 = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Hover/focus o tarjetas elevadas.
  static const List<BoxShadow> e2 = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x07000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Diálogos, bottom sheets, popovers.
  static const List<BoxShadow> e3 = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Glow de color para CTAs primarios. Usar con discreción.
  static List<BoxShadow> tinted(Color color, {double opacity = 0.25}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
