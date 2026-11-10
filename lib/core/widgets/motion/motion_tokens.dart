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

  /// Contadores numéricos (totales, importes). Lo bastante largo para que se
  /// lea el movimiento, lo bastante corto para no hacer esperar al dato.
  static const Duration countUp = Duration(milliseconds: 650);

  /// Relleno de barras de progreso.
  static const Duration fill = Duration(milliseconds: 600);

  /// Entrada de elementos (fade + slide). Corta: el contenido tiene que estar
  /// disponible casi de inmediato, la animación solo suaviza su llegada.
  static const Duration entrance = Duration(milliseconds: 300);

  /// Retardo entre elementos de una entrada escalonada.
  static const Duration stagger = Duration(milliseconds: 40);

  /// Destello de "esto acaba de cambiar" (umbral de presupuesto, campo
  /// rellenado por IA…).
  static const Duration highlight = Duration(milliseconds: 700);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;

  /// true si el usuario ha pedido reducir animaciones (accesibilidad). Todas
  /// las animaciones de este kit se saltan al estado final en ese caso.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
