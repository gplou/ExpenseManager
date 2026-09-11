import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Nocturne · paleta de la app
///
/// Evolución in-place de la paleta anterior (Quiet Wealth): mismos tokens
/// canónicos, valores nuevos. Fondo azul-gris casi neutro, acento lila usado
/// como línea/brillo — nunca como relleno grande. Contraste por rampas
/// tonales, no por saturación. Los valores legacy (dustyTeal, boneWhite,
/// sageGreen…) se mantienen como aliases reapuntados para no romper
/// consumidores.
/// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Marca / acento ────────────────────────────────────────────────────────
  /// Acento de marca (light). Lila apagado — línea, borde, icono; no relleno.
  static const Color inkBlue        = Color(0xFF6A5CC6);
  /// Fondo tintado del acento (light) — chips/badges/selected states.
  static const Color inkBlueSoft    = Color(0xFFE7E5FE);
  /// Acento (dark) — debe alcanzar AA sobre ink/inkDark.
  static const Color inkBlueLight   = Color(0xFF9184D9);
  /// Fondo tintado del acento (dark).
  static const Color inkBlueSoftDark = Color(0xFF2B2741);
  /// Texto/icono legible sobre [inkBlueSoft] (light) — más profundo que
  /// [inkBlue] para no perder contraste sobre el tinte pálido.
  static const Color inkBlueDeep    = Color(0xFF4B409A);
  /// Texto/icono legible sobre [inkBlueSoftDark] (dark) — más claro que
  /// [inkBlueLight] para no perder contraste sobre el tinte oscuro.
  static const Color inkBlueDeepDark = Color(0xFFD2CEFD);

  // ── Superficies light ─────────────────────────────────────────────────────
  /// Scaffold: azul-gris casi neutro. No es blanco puro.
  static const Color paper          = Color(0xFFF3F3F8);
  /// Card / surface principal.
  static const Color surface        = Color(0xFFFFFFFF);
  /// Superficie elevada / agrupada (raised).
  static const Color raised         = Color(0xFFEBECF3);
  /// Hairline divider — sutil pero visible sobre paper.
  static const Color divider        = Color(0xFFDCDDE8);
  /// Borde más marcado (activo, focused).
  static const Color borderStrong   = Color(0xFFC5C7D6);

  // ── Texto light ───────────────────────────────────────────────────────────
  /// Texto principal.
  static const Color ink            = Color(0xFF1B1C28);
  /// Texto secundario.
  static const Color graphite       = Color(0xFF6B6F82);
  /// Hints, labels secundarios.
  static const Color graphiteSoft   = Color(0xFF9295A8);
  /// Decorativo. NO usar para texto.
  static const Color whisper        = Color(0xFFB7B9C8);

  // ── Acentos semánticos (apagados, no chillones) ───────────────────────────
  // Nocturne define ok/warn/over en OKLCH (L 0.70-0.74) pensados para texto
  // sobre fondo oscuro; usarlos literalmente aquí rompería el contraste en
  // light mode y en los usos de relleno sólido (colorScheme.secondary/error).
  // Se mantienen los tonos actuales — ya comparten familia de matiz
  // (verde/ámbar/coral apagados) y funcionan en ambos modos vía el patrón
  // color-base + *Soft ya establecido.
  /// Income / positive. Sage profundo, no verde primario.
  static const Color positive       = Color(0xFF3C7A5C);
  static const Color positiveSoft   = Color(0xFFDCE7E0);
  /// Expense / negative. Coral apagado, no rojo chillón.
  static const Color negative       = Color(0xFFB8543F);
  static const Color negativeSoft   = Color(0xFFF3E1DB);
  /// Warning. Ámbar apagado tipo mostaza vieja.
  static const Color warning        = Color(0xFFB8842C);
  static const Color warningSoft    = Color(0xFFF3EAD3);

  // ── Superficies dark ──────────────────────────────────────────────────────
  /// Scaffold dark. Azul-gris casi neutro — no es negro puro.
  static const Color paperDark      = Color(0xFF161826);
  /// Card / surface dark.
  static const Color surfaceDarkMode = Color(0xFF232532);
  /// Superficie elevada dark. También usada como fondo del teclado numérico
  /// (token "keypad" de Nocturne — no hace falta un campo separado).
  static const Color raisedDark     = Color(0xFF292B31);
  /// Divider dark — sube luminosidad para que se vea sobre paperDark.
  static const Color dividerDark    = Color(0xFF3F424D);
  /// Borde marcado dark.
  static const Color borderStrongDark = Color(0xFF565A68);

  /// Texto principal dark.
  static const Color inkDark        = Color(0xFFE9E9ED);
  static const Color graphiteDark   = Color(0xFF9397AB);
  static const Color graphiteSoftDark = Color(0xFF6F7386);
  static const Color whisperDark    = Color(0xFF52566A);

  // ── Categorías curadas (14 colores armónicos) ─────────────────────────────
  /// Todos comparten saturación moderada para convivir en gráficas sin chillar.
  static const Color catFood          = Color(0xFFC16A4F); // terracota
  static const Color catTransport     = Color(0xFF586674); // slate
  static const Color catHome          = Color(0xFF7D8951); // oliva
  static const Color catHealth        = Color(0xFF5C8775); // sage
  static const Color catEntertainment = Color(0xFF824D63); // wine
  static const Color catShopping      = Color(0xFF967455); // taupe
  static const Color catEducation     = Color(0xFF2D447B); // ink azul medio
  static const Color catBills         = Color(0xFF4A4D52); // graphite
  static const Color catTravel        = Color(0xFF5B8189); // teal apagado
  static const Color catPersonal      = Color(0xFFA87887); // rosa polvo
  static const Color catSubscriptions = Color(0xFF6E5A86); // púrpura apagado
  static const Color catSalary        = Color(0xFF4E7B5E); // green deep
  static const Color catInvestments   = Color(0xFFA88150); // ochre
  static const Color catOther         = Color(0xFF7A7872); // neutro

  /// Escala ordenada para usar en charts / leyendas.
  static const List<Color> categoryScale = [
    catFood, catTransport, catHome, catHealth, catEntertainment,
    catShopping, catEducation, catBills, catTravel, catPersonal,
    catSubscriptions, catSalary, catInvestments, catOther,
  ];

  // ── Sombras (humo, no negro puro) ─────────────────────────────────────────
  /// Preferir [AppElevation] para nuevas implementaciones; estos quedan para
  /// retrocompatibilidad.
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x0F0B0F0C), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x070B0F0C), blurRadius: 4,  offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> softShadowSm = [
    BoxShadow(color: Color(0x0A0B0F0C), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> shadowGreen = [
    BoxShadow(color: Color(0x223C7A5C), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> shadowCoral = [
    BoxShadow(color: Color(0x22B8543F), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> shadowAmber = [
    BoxShadow(color: Color(0x22B8842C), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> shadowBlack = [
    BoxShadow(color: Color(0x140B0F0C), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // Aliases sombras
  static const List<BoxShadow> shadowPink   = shadowCoral;
  static const List<BoxShadow> shadowYellow = shadowAmber;

  // Glows
  static List<BoxShadow> glowGreen(double alpha) => [
        BoxShadow(color: positive.withValues(alpha: alpha), blurRadius: 24),
      ];
  static List<BoxShadow> glowCoral(double alpha) => [
        BoxShadow(color: negative.withValues(alpha: alpha), blurRadius: 24),
      ];
  static List<BoxShadow> glowPink(double alpha) => glowCoral(alpha);

  // ═══════════════════════════════════════════════════════════════════════════
  // Aliases legacy — apuntan a los tokens nuevos para no romper consumidores.
  // No usar en código nuevo: preferir los tokens canónicos de arriba.
  // ═══════════════════════════════════════════════════════════════════════════

  // Backgrounds / surfaces (light)
  static const Color boneWhite        = paper;
  static const Color pureWhite        = surface;
  static const Color surfaceElevated  = raised;

  // Marca y semánticos
  static const Color dustyTeal        = inkBlue;
  static const Color dustyTealLight   = inkBlueSoft;
  static const Color sageGreen        = positive;
  static const Color sageGreenLight   = positiveSoft;
  static const Color mutedTerra       = negative;
  static const Color mutedTerraLight  = negativeSoft;
  static const Color warmAmber        = warning;
  static const Color warmAmberLight   = warningSoft;

  // Texto
  static const Color textDark         = ink;
  static const Color textMuted        = graphite;
  static const Color textTertiary     = graphiteSoft;
  static const Color textSubtle       = whisper;

  // Borders
  static const Color borderLight      = divider;
  static const Color borderMedium     = borderStrong;

  // Dark palette
  static const Color darkBg           = paperDark;
  static const Color darkSurface      = surfaceDarkMode;
  static const Color darkSurfaceHigh  = raisedDark;
  static const Color darkBorderColor  = dividerDark;
  static const Color darkText         = inkDark;
  static const Color darkTextMuted    = graphiteDark;

  // Semantic aliases
  static const Color income           = positive;
  static const Color expense          = negative;
  static const Color primary          = inkBlue;
  static const Color secondary        = positive;

  // Compatibility aliases (zoo histórico)
  static const Color calmGreen        = positive;
  static const Color softCoral        = negative;
  static const Color calmGreenDark    = positive;
  static const Color softCoralDark    = negative;
  static const Color warmAmberDark    = warning;
  static const Color slateBlue        = inkBlue;
  static const Color electricBlue     = inkBlue;

  static const Color backgroundDark   = paperDark;
  static const Color surfaceDark      = surfaceDarkMode;
  static const Color carbonBlack      = paperDark;
  static const Color deepBlack        = surfaceDarkMode;
  static const Color midBlack         = raisedDark;
  static const Color darkBorder       = dividerDark;
  static const Color bruteBorder      = dividerDark;
  static const Color cream            = inkDark;

  static const Color lightBg            = paper;
  static const Color lightSurface       = surface;
  static const Color lightSurfaceHigh   = raised;
  static const Color lightBorder        = divider;
  static const Color lightBorderStrong  = borderStrong;
  static const Color lightText          = ink;
  static const Color lightTextMuted     = graphite;

  static const Color neonGreen        = positive;
  static const Color acidPink         = negative;
  static const Color vibrantYellow    = warning;

  static const Color priorityHigh     = negative;
  static const Color priorityMedium   = warning;
  static const Color priorityLow      = positive;
}
