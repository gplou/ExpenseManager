import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Nocturne · theme de la app
///
/// Evolución in-place del sistema anterior (Quiet Wealth): interfaz oscura,
/// tranquila y compacta. Tipografía Inter en peso medio (400/500, nunca
/// 600+), radios suaves de 8px, acento usado como línea y brillo — no como
/// relleno grande. Contraste por rampas tonales, no por saturación.
/// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  // ── LIGHT THEME (principal) ───────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        extensions: const [AppSemanticColors.light],
        scaffoldBackgroundColor: AppColors.paper,
        fontFamily: 'Inter',
        splashFactory: InkSparkle.splashFactory,
        colorScheme: const ColorScheme.light(
          primary: AppColors.inkBlue,
          onPrimary: AppColors.paper,
          secondary: AppColors.positive,
          onSecondary: AppColors.paper,
          tertiary: AppColors.warning,
          onTertiary: AppColors.paper,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          surfaceContainerLowest: AppColors.paper,
          surfaceContainerLow: Color(0xFFF6F3EC),
          surfaceContainer: AppColors.surface,
          surfaceContainerHigh: AppColors.raised,
          surfaceContainerHighest: Color(0xFFE8E4DB),
          error: AppColors.negative,
          onError: AppColors.paper,
          outline: AppColors.divider,
          outlineVariant: AppColors.raised,
        ),

        // ── AppBar — discreto, sin elevación ──────────────────────────────
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.paper,
          foregroundColor: AppColors.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          titleTextStyle: TextStyle(fontFamily: 'Inter', 
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
            letterSpacing: -0.17,
          ),
        ),

        // ── Cards — fondo surface, radio 8, hairline, sin sombra ──────────
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLg,
            side: BorderSide(color: AppColors.divider, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),

        // ── FAB — glow de acento, no relleno sólido pesado ────────────────
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.inkBlue,
          foregroundColor: AppColors.paper,
          shape: CircleBorder(),
          sizeConstraints: BoxConstraints.tightFor(width: 60, height: 60),
          iconSize: 26,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
        ),

        // ── ElevatedButton (CTA primario) — borde de acento, fondo
        // transparente. El acento va como línea/brillo, nunca como relleno.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.inkBlue,
            disabledForegroundColor: AppColors.graphiteSoft,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            side: const BorderSide(color: AppColors.inkBlue, width: 1),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(
              AppColors.inkBlue.withValues(alpha: 0.08),
            ),
          ),
        ),

        // ── FilledButton (CTA de hoja) — fondo accentTint, texto accentDeep
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.inkBlueSoft,
            foregroundColor: AppColors.inkBlueDeep,
            disabledBackgroundColor: AppColors.raised,
            disabledForegroundColor: AppColors.graphiteSoft,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),

        // ── OutlinedButton (secundario, neutro) ───────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.borderStrong, width: 1),
            minimumSize: const Size(double.infinity, 52),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),

        // ── TextButton ────────────────────────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.inkBlue,
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),

        // ── Inputs — fill sutil, focus con línea de acento ────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.raised,
          border: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: Colors.transparent, width: 1),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: Colors.transparent, width: 1),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.inkBlue, width: 1.5),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.negative, width: 1.5),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.negative, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          labelStyle: TextStyle(fontFamily: 'Inter', 
            color: AppColors.graphite,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(fontFamily: 'Inter', 
            color: AppColors.graphiteSoft,
            fontWeight: FontWeight.w400,
          ),
        ),

        // ── Chips / segmented — transparente por defecto, borde 1px;
        // seleccionado con fondo accentTint + texto accentDeep ────────────
        chipTheme: ChipThemeData(
          backgroundColor: Colors.transparent,
          selectedColor: AppColors.inkBlueSoft,
          labelStyle: TextStyle(fontFamily: 'Inter', 
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.ink,
            letterSpacing: 0.1,
          ),
          secondaryLabelStyle: TextStyle(fontFamily: 'Inter', 
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.inkBlueDeep,
            letterSpacing: 0.1,
          ),
          side: const BorderSide(color: AppColors.divider, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusPill),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),

        // ── Switch ───────────────────────────────────────────────────────
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.paper : AppColors.borderStrong,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.inkBlue : AppColors.raised,
          ),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),

        // ── SegmentedButton — borde de acento en el seleccionado ──────────
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.transparent,
            selectedBackgroundColor: AppColors.inkBlueSoft,
            selectedForegroundColor: AppColors.inkBlueDeep,
            foregroundColor: AppColors.graphite,
            side: const BorderSide(color: AppColors.divider, width: 1),
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontWeight: FontWeight.w500,
              fontSize: 13,
              letterSpacing: 0,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
          ),
        ),

        // ── ProgressIndicator ────────────────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.inkBlue,
          linearTrackColor: AppColors.raised,
          circularTrackColor: AppColors.raised,
        ),

        // ── Divider — hairline que se desvanece en los extremos vive en
        // FadingDivider (lib/core/widgets/); aquí solo el default sólido ──
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),

        // ── Drawer ───────────────────────────────────────────────────────
        drawerTheme: const DrawerThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          scrimColor: Color(0x52000000),
        ),

        // ── BottomSheet — radio 24 arriba, handle 36×4 en border ──────────
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusSheet,
          ),
          showDragHandle: true,
          dragHandleColor: AppColors.borderStrong,
          dragHandleSize: Size(36, 4),
        ),

        // ── Dialog ───────────────────────────────────────────────────────
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.radiusXl,
          ),
          shadowColor: const Color(0x1F000000),
          titleTextStyle: TextStyle(fontFamily: 'Inter', 
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
            letterSpacing: -0.22,
          ),
          contentTextStyle: TextStyle(fontFamily: 'Inter', 
            fontSize: 14,
            color: AppColors.graphite,
            height: 1.55,
          ),
        ),

        // ── SnackBar ─────────────────────────────────────────────────────
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.ink,
          contentTextStyle: TextStyle(fontFamily: 'Inter', 
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.paper,
          ),
          actionTextColor: AppColors.inkBlueLight,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.radiusMd,
          ),
        ),

        // ── Text ─────────────────────────────────────────────────────────
        textTheme: _buildTextTheme(AppColors.ink, AppColors.graphite),
      );

  // ── DARK THEME ───────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        extensions: const [AppSemanticColors.dark],
        scaffoldBackgroundColor: AppColors.paperDark,
        fontFamily: 'Inter',
        splashFactory: InkSparkle.splashFactory,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.inkBlueLight,
          onPrimary: AppColors.paperDark,
          secondary: AppColors.positive,
          onSecondary: AppColors.inkDark,
          tertiary: AppColors.warning,
          onTertiary: AppColors.paperDark,
          surface: AppColors.surfaceDarkMode,
          onSurface: AppColors.inkDark,
          surfaceContainerLowest: AppColors.paperDark,
          surfaceContainerLow: Color(0xFF111316),
          surfaceContainer: AppColors.surfaceDarkMode,
          surfaceContainerHigh: AppColors.raisedDark,
          surfaceContainerHighest: Color(0xFF2A2E35),
          error: AppColors.negative,
          onError: AppColors.inkDark,
          outline: AppColors.dividerDark,
          outlineVariant: AppColors.raisedDark,
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.paperDark,
          foregroundColor: AppColors.inkDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(fontFamily: 'Inter', 
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: AppColors.inkDark,
            letterSpacing: -0.17,
          ),
        ),

        cardTheme: const CardThemeData(
          color: AppColors.surfaceDarkMode,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLg,
            side: BorderSide(color: AppColors.dividerDark, width: 1),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.inkBlueLight,
          foregroundColor: AppColors.paperDark,
          shape: CircleBorder(),
          sizeConstraints: BoxConstraints.tightFor(width: 60, height: 60),
          iconSize: 26,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.inkBlueLight,
            disabledForegroundColor: AppColors.graphiteSoftDark,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            side: const BorderSide(color: AppColors.inkBlueLight, width: 1),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(
              AppColors.inkBlueLight.withValues(alpha: 0.10),
            ),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.inkBlueSoftDark,
            foregroundColor: AppColors.inkBlueDeepDark,
            disabledBackgroundColor: AppColors.raisedDark,
            disabledForegroundColor: AppColors.graphiteSoftDark,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.inkDark,
            side: const BorderSide(color: AppColors.borderStrongDark, width: 1),
            minimumSize: const Size(double.infinity, 52),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.inkBlueLight,
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.raisedDark,
          border: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: Colors.transparent, width: 1),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: Colors.transparent, width: 1),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.inkBlueLight, width: 1.5),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.negative, width: 1.5),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.negative, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          labelStyle: TextStyle(fontFamily: 'Inter', 
            color: AppColors.graphiteDark,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(fontFamily: 'Inter', 
            color: AppColors.graphiteSoftDark,
            fontWeight: FontWeight.w400,
          ),
        ),

        chipTheme: ChipThemeData(
          backgroundColor: Colors.transparent,
          selectedColor: AppColors.inkBlueSoftDark,
          labelStyle: TextStyle(fontFamily: 'Inter', 
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.inkDark,
            letterSpacing: 0.1,
          ),
          secondaryLabelStyle: TextStyle(fontFamily: 'Inter', 
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.inkBlueDeepDark,
            letterSpacing: 0.1,
          ),
          side: const BorderSide(color: AppColors.dividerDark, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusPill),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.paperDark : AppColors.borderStrongDark,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.inkBlueLight : AppColors.raisedDark,
          ),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),

        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.transparent,
            selectedBackgroundColor: AppColors.inkBlueSoftDark,
            selectedForegroundColor: AppColors.inkBlueDeepDark,
            foregroundColor: AppColors.graphiteDark,
            side: const BorderSide(color: AppColors.dividerDark, width: 1),
            textStyle: TextStyle(fontFamily: 'Inter', 
              fontWeight: FontWeight.w500,
              fontSize: 13,
              letterSpacing: 0,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
          ),
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.inkBlueLight,
          linearTrackColor: AppColors.raisedDark,
          circularTrackColor: AppColors.raisedDark,
        ),

        dividerTheme: const DividerThemeData(
          color: AppColors.dividerDark,
          thickness: 1,
          space: 1,
        ),

        drawerTheme: const DrawerThemeData(
          backgroundColor: AppColors.surfaceDarkMode,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          scrimColor: Color(0x73000000),
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceDarkMode,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusSheet,
          ),
          showDragHandle: true,
          dragHandleColor: AppColors.borderStrongDark,
          dragHandleSize: Size(36, 4),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceDarkMode,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.radiusXl,
            side: BorderSide(color: AppColors.dividerDark, width: 1),
          ),
          titleTextStyle: TextStyle(fontFamily: 'Inter', 
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppColors.inkDark,
            letterSpacing: -0.22,
          ),
          contentTextStyle: TextStyle(fontFamily: 'Inter', 
            fontSize: 14,
            color: AppColors.graphiteDark,
            height: 1.55,
          ),
        ),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.raisedDark,
          contentTextStyle: TextStyle(fontFamily: 'Inter', 
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.inkDark,
          ),
          actionTextColor: AppColors.inkBlueLight,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.radiusMd,
          ),
        ),

        textTheme: _buildTextTheme(AppColors.inkDark, AppColors.graphiteDark),
      );

  // ── Tipografía Nocturne ──────────────────────────────────────────────────
  //
  // Inter, pesos 400/500 únicamente (nunca 600+, ni en títulos). Escala densa
  // (~0.7× de la anterior). letterSpacing negativo (-0.02em) en la franja
  // display/headline; labelMedium es el estilo "kicker" — úsalo con
  // `.toUpperCase()` para eyebrows/section heads.
  static TextTheme _buildTextTheme(Color primary, Color muted) => TextTheme(
        // Hero numbers (balance, totales en cards)
        displayLarge: TextStyle(fontFamily: 'Inter', 
          fontSize: 46, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: -0.92, height: 1.05,
        ),
        displayMedium: TextStyle(fontFamily: 'Inter', 
          fontSize: 38, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: -0.76, height: 1.08,
        ),
        displaySmall: TextStyle(fontFamily: 'Inter', 
          fontSize: 32, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: -0.64, height: 1.12,
        ),

        // Headlines (section headers)
        headlineLarge: TextStyle(fontFamily: 'Inter', 
          fontSize: 28, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: -0.56, height: 1.18,
        ),
        headlineMedium: TextStyle(fontFamily: 'Inter', 
          fontSize: 25, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: -0.5, height: 1.22,
        ),
        headlineSmall: TextStyle(fontFamily: 'Inter', 
          fontSize: 24, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: -0.48, height: 1.25,
        ),

        // Titles (card titles, list section heads)
        titleLarge: TextStyle(fontFamily: 'Inter', 
          fontSize: 22, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: -0.22, height: 1.3,
        ),
        titleMedium: TextStyle(fontFamily: 'Inter', 
          fontSize: 17, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: -0.17, height: 1.35,
        ),
        titleSmall: TextStyle(fontFamily: 'Inter', 
          fontSize: 15, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: -0.15, height: 1.4,
        ),

        // Body
        bodyLarge: TextStyle(fontFamily: 'Inter', 
          fontSize: 15, fontWeight: FontWeight.w400,
          color: primary, height: 1.55,
        ),
        bodyMedium: TextStyle(fontFamily: 'Inter', 
          fontSize: 14, fontWeight: FontWeight.w400,
          color: primary, height: 1.55,
        ),
        bodySmall: TextStyle(fontFamily: 'Inter', 
          fontSize: 13, fontWeight: FontWeight.w400,
          color: muted, height: 1.5,
        ),

        // Labels (UI chips, badges, botones, tabs)
        labelLarge: TextStyle(fontFamily: 'Inter', 
          fontSize: 13, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: 0.1, height: 1.4,
        ),
        // Kicker — usa con `.toUpperCase()` para eyebrows / section heads.
        labelMedium: TextStyle(fontFamily: 'Inter', 
          fontSize: 12, fontWeight: FontWeight.w500,
          color: muted, letterSpacing: 0.96,
        ),
        labelSmall: TextStyle(fontFamily: 'Inter', 
          fontSize: 11, fontWeight: FontWeight.w500,
          color: muted, letterSpacing: 0.3,
        ),
      );
}
