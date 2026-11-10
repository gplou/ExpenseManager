import 'package:flutter/widgets.dart';

/// Duraciones y curvas compartidas por las micro-animaciones de la app.
///
/// Centralizarlas evita que cada pantalla invente su propio "ritmo": todo lo
/// que entra, se rellena o responde a un toque se mueve con la misma cadencia.
abstract final class MotionTokens {
  /// Respuesta al toque (hundirse al pulsar).
  static const Duration press = Duration(milliseconds: 90);

  /// Rebote al soltar.
  static const Duration release = Duration(milliseconds: 280);

  /// Contadores numéricos (totales, importes).
  static const Duration countUp = Duration(milliseconds: 900);

  /// Relleno de barras de progreso.
  static const Duration fill = Duration(milliseconds: 750);

  /// Entrada de elementos (fade + slide).
  static const Duration entrance = Duration(milliseconds: 420);

  /// Retardo entre elementos de una entrada escalonada.
  static const Duration stagger = Duration(milliseconds: 60);

  /// Destello de "esto acaba de cambiar" (umbral de presupuesto, campo
  /// rellenado por IA…).
  static const Duration highlight = Duration(milliseconds: 900);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;

  /// true si el usuario ha pedido reducir animaciones (accesibilidad). Todas
  /// las animaciones de este kit se saltan al estado final en ese caso.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
