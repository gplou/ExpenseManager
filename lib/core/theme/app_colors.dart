import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Paleta "Calm Financial" ────────────────────────────────────────────────

  // Fondos & superficies (light)
  static const Color boneWhite       = Color(0xFFF8F7F2); // fondo principal
  static const Color pureWhite       = Color(0xFFFFFFFF); // tarjetas
  static const Color surfaceElevated = Color(0xFFF0EDE7); // superficie elevada

  // Acentos principales
  static const Color dustyTeal       = Color(0xFF7A9A99); // primario (azul-verde polvoriento)
  static const Color dustyTealLight  = Color(0xFFD6E4E3); // fondo pastel teal
  static const Color sageGreen       = Color(0xFFA3B18A); // ingresos (verde salvia)
  static const Color sageGreenLight  = Color(0xFFDFE8D5); // fondo pastel sage
  static const Color mutedTerra      = Color(0xFFC1917A); // gastos (terracota desaturada)
  static const Color mutedTerraLight = Color(0xFFF0DDD6); // fondo pastel terra
  static const Color warmAmber       = Color(0xFFB5956B); // alertas / fechas
  static const Color warmAmberLight  = Color(0xFFF0E5D5); // fondo pastel amber

  // Texto
  static const Color textDark        = Color(0xFF333333); // texto principal
  static const Color textMuted       = Color(0xFF7A7875); // texto secundario
  static const Color textSubtle      = Color(0xFFB0ADA8); // texto muy sutil

  // Bordes
  static const Color borderLight     = Color(0xFFE8E5DF); // borde sutil
  static const Color borderMedium    = Color(0xFFCBC8C1); // borde activo / fuerte

  // ── Paleta dark (neutra cálida) ───────────────────────────────────────────
  static const Color darkBg          = Color(0xFF1E2329);
  static const Color darkSurface     = Color(0xFF252C33);
  static const Color darkSurfaceHigh = Color(0xFF2D353D);
  static const Color darkBorderColor = Color(0xFF3C4650);
  static const Color darkText        = Color(0xFFE8E5DF);
  static const Color darkTextMuted   = Color(0xFF8A9296);

  // ── Sombras suaves ────────────────────────────────────────────────────────
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x07000000), blurRadius: 4,  offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> softShadowSm = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowGreen = [
    BoxShadow(color: Color(0x2AA3B18A), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowCoral = [
    BoxShadow(color: Color(0x2AC1917A), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowAmber = [
    BoxShadow(color: Color(0x2AB5956B), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowBlack = [
    BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // Aliases de sombra legacy
  static const List<BoxShadow> shadowPink   = shadowCoral;
  static const List<BoxShadow> shadowYellow = shadowAmber;

  // Glows para gráficos y balance hero
  static List<BoxShadow> glowGreen(double alpha) => [
    BoxShadow(color: sageGreen.withValues(alpha: alpha), blurRadius: 20),
  ];
  static List<BoxShadow> glowCoral(double alpha) => [
    BoxShadow(color: mutedTerra.withValues(alpha: alpha), blurRadius: 20),
  ];
  static List<BoxShadow> glowPink(double alpha) => glowCoral(alpha);

  // ── Aliases semánticos ────────────────────────────────────────────────────
  static const Color income  = sageGreen;
  static const Color expense = mutedTerra;

  static const Color primary   = dustyTeal;
  static const Color secondary = sageGreen;

  // Semantic (compatibilidad con código existente)
  static const Color calmGreen     = sageGreen;
  static const Color softCoral     = mutedTerra;
  static const Color calmGreenDark = sageGreen;
  static const Color softCoralDark = mutedTerra;
  static const Color warmAmberDark = warmAmber;
  static const Color slateBlue     = dustyTeal;
  static const Color electricBlue  = dustyTeal;

  // Fondos dark (aliases legacy)
  static const Color backgroundDark = darkBg;
  static const Color surfaceDark    = darkSurface;
  static const Color carbonBlack    = darkBg;
  static const Color deepBlack      = darkSurface;
  static const Color midBlack       = darkSurfaceHigh;
  static const Color darkBorder     = darkBorderColor;
  static const Color bruteBorder    = darkBorderColor;
  static const Color cream          = darkText;

  // Light (aliases legacy)
  static const Color lightBg           = boneWhite;
  static const Color lightSurface      = pureWhite;
  static const Color lightSurfaceHigh  = surfaceElevated;
  static const Color lightBorder       = borderLight;
  static const Color lightBorderStrong = borderMedium;
  static const Color lightText         = textDark;
  static const Color lightTextMuted    = textMuted;

  // Legacy neon → calm (usados inline en pantallas)
  static const Color neonGreen     = sageGreen;
  static const Color acidPink      = mutedTerra;
  static const Color vibrantYellow = warmAmber;

  // Prioridades de tareas
  static const Color priorityHigh   = mutedTerra;
  static const Color priorityMedium = warmAmber;
  static const Color priorityLow    = sageGreen;
}
