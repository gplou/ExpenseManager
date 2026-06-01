import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Quiet Wealth · theme de la app
///
/// Sistema editorial calmado: papel cálido + tinta azul profunda, tipografía
/// humanista General Sans, radios generosos, sombras de humo. La identidad
/// vive en la jerarquía tipográfica y el espacio, no en color saturado.
/// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'GeneralSans';

  // ── LIGHT THEME (principal) ───────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        extensions: const [AppSemanticColors.light],
        scaffoldBackgroundColor: AppColors.paper,
        fontFamily: _fontFamily,
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
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.paper,
          foregroundColor: AppColors.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: -0.4,
          ),
        ),

        // ── Cards ─────────────────────────────────────────────────────────
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

        // ── FAB ───────────────────────────────────────────────────────────
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

        // ── ElevatedButton ────────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.inkBlue,
            foregroundColor: AppColors.paper,
            disabledBackgroundColor: AppColors.raised,
            disabledForegroundColor: AppColors.graphite,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),

        // ── OutlinedButton ────────────────────────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.borderStrong, width: 1),
            minimumSize: const Size(double.infinity, 52),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),

        // ── TextButton ────────────────────────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.inkBlue,
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),

        // ── Inputs — fill cálido, focus tinte marca ───────────────────────
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.raised,
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: Colors.transparent, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: Colors.transparent, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.inkBlue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.negative, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.negative, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          labelStyle: TextStyle(
            fontFamily: _fontFamily,
            color: AppColors.graphite,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            fontFamily: _fontFamily,
            color: AppColors.graphiteSoft,
            fontWeight: FontWeight.w400,
          ),
        ),

        // ── Chips ─────────────────────────────────────────────────────────
        chipTheme: const ChipThemeData(
          backgroundColor: AppColors.raised,
          selectedColor: AppColors.inkBlue,
          labelStyle: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.ink,
            letterSpacing: 0.1,
          ),
          secondaryLabelStyle: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.paper,
            letterSpacing: 0.1,
          ),
          side: BorderSide(color: Colors.transparent, width: 0),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusPill),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

        // ── SegmentedButton ──────────────────────────────────────────────
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: AppColors.raised,
            selectedBackgroundColor: AppColors.surface,
            selectedForegroundColor: AppColors.ink,
            foregroundColor: AppColors.graphite,
            side: BorderSide.none,
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
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

        // ── Divider — hairline ─────────────────────────────────────────────
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
          scrimColor: Color(0x520B0F0C),
        ),

        // ── BottomSheet ──────────────────────────────────────────────────
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusSheet,
          ),
          showDragHandle: true,
          dragHandleColor: AppColors.borderStrong,
        ),

        // ── Dialog ───────────────────────────────────────────────────────
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusXl,
          ),
          shadowColor: Color(0x140B0F0C),
          titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
          contentTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            color: AppColors.graphite,
            height: 1.55,
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
        fontFamily: _fontFamily,
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

        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.paperDark,
          foregroundColor: AppColors.inkDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.inkDark,
            letterSpacing: -0.4,
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
            backgroundColor: AppColors.inkBlueLight,
            foregroundColor: AppColors.paperDark,
            disabledBackgroundColor: AppColors.raisedDark,
            disabledForegroundColor: AppColors.graphiteDark,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.inkBlueLight,
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.raisedDark,
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: Colors.transparent, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: Colors.transparent, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.inkBlueLight, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.negative, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.negative, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          labelStyle: TextStyle(
            fontFamily: _fontFamily,
            color: AppColors.graphiteDark,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            fontFamily: _fontFamily,
            color: AppColors.graphiteSoftDark,
            fontWeight: FontWeight.w400,
          ),
        ),

        chipTheme: const ChipThemeData(
          backgroundColor: AppColors.raisedDark,
          selectedColor: AppColors.inkBlueLight,
          labelStyle: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.inkDark,
            letterSpacing: 0.1,
          ),
          secondaryLabelStyle: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.paperDark,
            letterSpacing: 0.1,
          ),
          side: BorderSide(color: Colors.transparent, width: 0),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusPill),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            backgroundColor: AppColors.raisedDark,
            selectedBackgroundColor: AppColors.surfaceDarkMode,
            selectedForegroundColor: AppColors.inkDark,
            foregroundColor: AppColors.graphiteDark,
            side: BorderSide.none,
            textStyle: const TextStyle(
              fontFamily: _fontFamily,
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
          scrimColor: Color(0x520B0F0C),
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceDarkMode,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusSheet,
          ),
          showDragHandle: true,
          dragHandleColor: AppColors.borderStrongDark,
        ),

        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.surfaceDarkMode,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusXl,
            side: BorderSide(color: AppColors.dividerDark, width: 1),
          ),
          titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.inkDark,
            letterSpacing: -0.3,
          ),
          contentTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            color: AppColors.graphiteDark,
            height: 1.55,
          ),
        ),

        textTheme: _buildTextTheme(AppColors.inkDark, AppColors.graphiteDark),
      );

  // ── Tipografía Quiet Wealth ───────────────────────────────────────────────
  //
  // GeneralSans tiene 5 pesos (300–700). Tracking apretado en displays para
  // sensación editorial; pesos altos solo en hero numbers, el resto vive en
  // 400/500/600. Heights cómodos para lectura calmada.
  static TextTheme _buildTextTheme(Color primary, Color muted) => TextTheme(
        // Hero numbers (balance, totales en cards)
        displayLarge: TextStyle(
          fontFamily: _fontFamily, fontSize: 52, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -2.0, height: 1.05,
        ),
        displayMedium: TextStyle(
          fontFamily: _fontFamily, fontSize: 42, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -1.4, height: 1.08,
        ),
        displaySmall: TextStyle(
          fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.w600,
          color: primary, letterSpacing: -0.9, height: 1.12,
        ),

        // Headlines (section headers)
        headlineLarge: TextStyle(
          fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w600,
          color: primary, letterSpacing: -0.6, height: 1.18,
        ),
        headlineMedium: TextStyle(
          fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w600,
          color: primary, letterSpacing: -0.4, height: 1.25,
        ),
        headlineSmall: TextStyle(
          fontFamily: _fontFamily, fontSize: 19, fontWeight: FontWeight.w600,
          color: primary, letterSpacing: -0.3, height: 1.3,
        ),

        // Titles (card titles, list section heads)
        titleLarge: TextStyle(
          fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w600,
          color: primary, letterSpacing: -0.2, height: 1.35,
        ),
        titleMedium: TextStyle(
          fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: 0, height: 1.4,
        ),
        titleSmall: TextStyle(
          fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: 0, height: 1.4,
        ),

        // Body
        bodyLarge: TextStyle(
          fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w400,
          color: primary, height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w400,
          color: primary, height: 1.55,
        ),
        bodySmall: TextStyle(
          fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400,
          color: muted, height: 1.5,
        ),

        // Labels (UI chips, badges, "eyebrow" headers)
        labelLarge: TextStyle(
          fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w500,
          color: primary, letterSpacing: 0.1, height: 1.4,
        ),
        // Eyebrow style — usa con `.toUpperCase()` para section heads
        labelMedium: TextStyle(
          fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w600,
          color: muted, letterSpacing: 1.2,
        ),
        labelSmall: TextStyle(
          fontFamily: _fontFamily, fontSize: 10, fontWeight: FontWeight.w600,
          color: muted, letterSpacing: 1.4,
        ),
      );
}
