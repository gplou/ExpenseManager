import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Professional Fintech Palette ──────────────────────────────────────────

  // Backgrounds & surfaces (light)
  static const Color boneWhite       = Color(0xFFF8FAFC); // scaffold bg (slate-50)
  static const Color pureWhite       = Color(0xFFFFFFFF); // card surface
  static const Color surfaceElevated = Color(0xFFF1F5F9); // elevated surface (slate-100)

  // Primary — confident teal
  static const Color dustyTeal       = Color(0xFF0D9488); // primary (teal-600)
  static const Color dustyTealLight  = Color(0xFFCCFBF1); // teal background (teal-100)

  // Income — clear green
  static const Color sageGreen       = Color(0xFF16A34A); // income (green-600)
  static const Color sageGreenLight  = Color(0xFFDCFCE7); // income background (green-100)

  // Expense — coral red
  static const Color mutedTerra      = Color(0xFFE25445); // expense (warm coral-red)
  static const Color mutedTerraLight = Color(0xFFFFF1EE); // expense background (light coral)

  // Amber — premium / warnings
  static const Color warmAmber       = Color(0xFFD97706); // amber (amber-600)
  static const Color warmAmberLight  = Color(0xFFFEF3C7); // amber background (amber-100)

  // Text
  static const Color textDark        = Color(0xFF0F172A); // primary text (slate-900)
  static const Color textMuted       = Color(0xFF64748B); // secondary text (slate-500)
  static const Color textSubtle      = Color(0xFF94A3B8); // hint/subtle text (slate-400)

  // Borders
  static const Color borderLight     = Color(0xFFE2E8F0); // subtle border (slate-200)
  static const Color borderMedium    = Color(0xFFCBD5E1); // active border (slate-300)

  // ── Dark palette (slate) ──────────────────────────────────────────────────
  static const Color darkBg          = Color(0xFF0F172A); // scaffold bg (slate-900)
  static const Color darkSurface     = Color(0xFF1E293B); // card surface (slate-800)
  static const Color darkSurfaceHigh = Color(0xFF334155); // elevated surface (slate-700)
  static const Color darkBorderColor = Color(0xFF475569); // border (slate-600)
  static const Color darkText        = Color(0xFFF1F5F9); // primary text (slate-100)
  static const Color darkTextMuted   = Color(0xFF94A3B8); // secondary text (slate-400)

  // ── Shadows ───────────────────────────────────────────────────────────────
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x07000000), blurRadius: 4,  offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> softShadowSm = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowGreen = [
    BoxShadow(color: Color(0x2A16A34A), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowCoral = [
    BoxShadow(color: Color(0x2AE25445), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowAmber = [
    BoxShadow(color: Color(0x2AD97706), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowBlack = [
    BoxShadow(color: Color(0x18000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // Aliases
  static const List<BoxShadow> shadowPink   = shadowCoral;
  static const List<BoxShadow> shadowYellow = shadowAmber;

  // Glows
  static List<BoxShadow> glowGreen(double alpha) => [
    BoxShadow(color: sageGreen.withValues(alpha: alpha), blurRadius: 20),
  ];
  static List<BoxShadow> glowCoral(double alpha) => [
    BoxShadow(color: mutedTerra.withValues(alpha: alpha), blurRadius: 20),
  ];
  static List<BoxShadow> glowPink(double alpha) => glowCoral(alpha);

  // ── Semantic aliases ──────────────────────────────────────────────────────
  static const Color income  = sageGreen;
  static const Color expense = mutedTerra;

  static const Color primary   = dustyTeal;
  static const Color secondary = sageGreen;

  // Compatibility aliases
  static const Color calmGreen     = sageGreen;
  static const Color softCoral     = mutedTerra;
  static const Color calmGreenDark = sageGreen;
  static const Color softCoralDark = mutedTerra;
  static const Color warmAmberDark = warmAmber;
  static const Color slateBlue     = dustyTeal;
  static const Color electricBlue  = dustyTeal;

  static const Color backgroundDark = darkBg;
  static const Color surfaceDark    = darkSurface;
  static const Color carbonBlack    = darkBg;
  static const Color deepBlack      = darkSurface;
  static const Color midBlack       = darkSurfaceHigh;
  static const Color darkBorder     = darkBorderColor;
  static const Color bruteBorder    = darkBorderColor;
  static const Color cream          = darkText;

  static const Color lightBg           = boneWhite;
  static const Color lightSurface      = pureWhite;
  static const Color lightSurfaceHigh  = surfaceElevated;
  static const Color lightBorder       = borderLight;
  static const Color lightBorderStrong = borderMedium;
  static const Color lightText         = textDark;
  static const Color lightTextMuted    = textMuted;

  static const Color neonGreen     = sageGreen;
  static const Color acidPink      = mutedTerra;
  static const Color vibrantYellow = warmAmber;

  static const Color priorityHigh   = mutedTerra;
  static const Color priorityMedium = warmAmber;
  static const Color priorityLow    = sageGreen;
}
