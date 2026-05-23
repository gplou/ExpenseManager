import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Quiet Wealth · paleta de la app
///
/// Identidad: papel cálido + tinta azul profunda. Sobriedad editorial, no
/// opulencia. Los valores legacy (dustyTeal, boneWhite, sageGreen…) se
/// mantienen como aliases reapuntados para no romper consumidores.
/// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Marca ─────────────────────────────────────────────────────────────────
  /// Color de marca. Azul tinta profundo, tipo banca privada.
  static const Color inkBlue        = Color(0xFF1B2A4E);
  /// Variante para fondos suaves (chips, badges, selected states).
  static const Color inkBlueSoft    = Color(0xFFE3E8F2);
  /// Variante luminosa para dark mode (debe alcanzar AA sobre ink).
  static const Color inkBlueLight   = Color(0xFF8AA0CE);

  // ── Superficies light ─────────────────────────────────────────────────────
  /// Scaffold: papel cálido. No es blanco puro — suaviza la luz.
  static const Color paper          = Color(0xFFFAF8F4);
  /// Card / surface principal.
  static const Color surface        = Color(0xFFFFFFFF);
  /// Superficie elevada / agrupada (raised). Tinte cálido.
  static const Color raised         = Color(0xFFF2EFE9);
  /// Hairline divider — sutil pero visible sobre paper.
  static const Color divider        = Color(0xFFE0D9C8);
  /// Borde más marcado (activo, focused).
  static const Color borderStrong   = Color(0xFFCFC8B5);

  // ── Texto light ───────────────────────────────────────────────────────────
  /// Texto principal. Casi negro, ligerísimo tinte verde. 18.7:1 sobre paper.
  static const Color ink            = Color(0xFF0B0F0C);
  /// Texto secundario. 7.1:1 sobre paper — AA estricto AAA.
  static const Color graphite       = Color(0xFF5C625E);
  /// Hints, labels secundarios. 4.6:1 sobre paper — AA mínimo.
  static const Color graphiteSoft   = Color(0xFF7C8181);
  /// Decorativo. NO usar para texto (2.6:1).
  static const Color whisper        = Color(0xFF9AA09C);

  // ── Acentos semánticos (apagados, no chillones) ───────────────────────────
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
  /// Scaffold dark. No es negro puro — tinte cálido, evita el OLED frío.
  static const Color paperDark      = Color(0xFF0C0D0B);
  /// Card / surface dark.
  static const Color surfaceDarkMode = Color(0xFF15171A);
  /// Superficie elevada dark.
  static const Color raisedDark     = Color(0xFF1E2126);
  /// Divider dark — sube luminosidad para que se vea sobre paperDark.
  static const Color dividerDark    = Color(0xFF323841);
  /// Borde marcado dark.
  static const Color borderStrongDark = Color(0xFF4A515B);

  /// Texto principal dark — mismo papel del light invertido.
  static const Color inkDark        = Color(0xFFF2EFE9);
  static const Color graphiteDark   = Color(0xFFB7B5AE);
  static const Color graphiteSoftDark = Color(0xFF8F8E88);
  static const Color whisperDark    = Color(0xFF6C6B66);

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
