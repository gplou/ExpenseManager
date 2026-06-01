import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Mode-dependent semantic color tokens exposed via [ThemeExtension] so widgets
/// can read `context.appColors.surface` instead of branching manually with
/// `isDark ? AppColors.surfaceDarkMode : AppColors.surface`.
///
/// Values are 1:1 with the existing [AppColors] light/dark constants — this is a
/// value-preserving indirection, not a re-theme. Mode-independent tokens
/// (accents `positive`/`negative`/`warning`, the brand `inkBlue`, category
/// colors, shadows) intentionally stay as `AppColors.*` constants.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.background,
    required this.surface,
    required this.raised,
    required this.divider,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textSoft,
  });

  /// Scaffold background (warm paper / near-black).
  final Color background;

  /// Card / primary surface.
  final Color surface;

  /// Elevated / grouped surface.
  final Color raised;

  /// Hairline divider.
  final Color divider;

  /// Stronger border (active/focused).
  final Color borderStrong;

  /// Primary text.
  final Color text;

  /// Secondary text.
  final Color textMuted;

  /// Tertiary / hint text.
  final Color textSoft;

  static const light = AppSemanticColors(
    background: AppColors.paper,
    surface: AppColors.surface,
    raised: AppColors.raised,
    divider: AppColors.divider,
    borderStrong: AppColors.borderStrong,
    text: AppColors.ink,
    textMuted: AppColors.graphite,
    textSoft: AppColors.graphiteSoft,
  );

  static const dark = AppSemanticColors(
    background: AppColors.paperDark,
    surface: AppColors.surfaceDarkMode,
    raised: AppColors.raisedDark,
    divider: AppColors.dividerDark,
    borderStrong: AppColors.borderStrongDark,
    text: AppColors.inkDark,
    textMuted: AppColors.graphiteDark,
    textSoft: AppColors.graphiteSoftDark,
  );

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? raised,
    Color? divider,
    Color? borderStrong,
    Color? text,
    Color? textMuted,
    Color? textSoft,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      divider: divider ?? this.divider,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSoft: textSoft ?? this.textSoft,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSoft: Color.lerp(textSoft, other.textSoft, t)!,
    );
  }
}
