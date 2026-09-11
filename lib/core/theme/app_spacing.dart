import 'package:flutter/widgets.dart';

/// Tokens de espaciado y radio.
///
/// Reemplaza valores literales repartidos por la app. Cualquier nuevo widget
/// debe usar estos tokens en vez de hardcodear `EdgeInsets.all(16)` o
/// `BorderRadius.circular(20)` directamente.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;

  // Helpers idiomáticos
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets paddingHorizontalLg =
      EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXl =
      EdgeInsets.symmetric(horizontal: xl);

  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl, width: xxl);
}

/// Tokens de border radius.
///
/// Escala Nocturne: 8 por defecto, 12 en botones grandes/hojas, 24 en el top
/// de bottom sheets, 999 en chips/pills. Escala intencional con propósito
/// documentado. No introducir valores nuevos sin justificación.
class AppRadius {
  AppRadius._();

  static const double xs = 8.0;       // badges, mini-icons
  static const double sm = 8.0;       // small icon containers
  static const double md = 12.0;      // segmented buttons, chips, buttons
  static const double lg = 8.0;       // cards, inputs (default)
  static const double xl = 16.0;      // hero cards, dialogs
  static const double xxl = 24.0;     // bottom sheets, big surfaces
  static const double sheet = 24.0;   // bottom sheets (top corners)
  static const double pill = 999.0;   // chips, pills

  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius radiusSheet =
      BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius radiusPill =
      BorderRadius.all(Radius.circular(pill));
}

/// Mínimos de tap target para WCAG / Material guidelines.
class AppTapTargets {
  AppTapTargets._();

  /// 48x48 lógicos: cumple WCAG 2.5.5 AAA y Material Design.
  static const double minSize = 48.0;
}

/// Tamaños de fuente para los emojis de categoría según su contexto.
///
/// Centraliza los `TextStyle(fontSize: ...)` que estaban repetidos en tiles,
/// listas, selectores y diálogos. No introducir valores nuevos sin justificar.
class AppEmojiSize {
  AppEmojiSize._();

  /// Strip compacto de categorías recientes.
  static const double small = 14.0;

  /// Tiles de transacción, lista, selector de categoría.
  static const double medium = 18.0;

  /// Picker de categorías y diálogos de creación (presencia grande).
  static const double large = 24.0;
}
