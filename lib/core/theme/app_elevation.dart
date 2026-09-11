import 'package:flutter/material.dart';

/// Escala de elevación Nocturne.
///
/// Elevación = borde + una sola sombra ambiental suave, nunca sombras
/// apiladas. Negro puro muy diluido (no tinte de color) para que funcione
/// igual sobre fondo claro u oscuro. `e1`–`e3` jerarquía progresiva; `tinted`
/// para glows de acento.
class AppElevation {
  AppElevation._();

  /// Sin sombra.
  static const List<BoxShadow> e0 = <BoxShadow>[];

  /// Reposo: tarjeta apenas separada del fondo.
  static const List<BoxShadow> e1 = [
    BoxShadow(
      color: Color(0x1A000000), // negro @ 10%
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  /// Hover/focus, hero cards y tarjetas elevadas. shadow-md de Nocturne.
  static const List<BoxShadow> e2 = [
    BoxShadow(
      color: Color(0x73000000), // negro @ 45%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Diálogos, bottom sheets, popovers.
  static const List<BoxShadow> e3 = [
    BoxShadow(
      color: Color(0x73000000),
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
  ];

  /// Glow de color para CTAs primarios (FAB, botón primario). Halo amplio y
  /// centrado — sin offset — para que lea como brillo, no como sombra.
  static List<BoxShadow> tinted(Color color, {double opacity = 0.28}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 24,
        ),
      ];
}
