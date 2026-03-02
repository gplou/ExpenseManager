import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── LIGHT THEME (principal) ───────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.boneWhite,
        fontFamily: 'Sora',
        colorScheme: const ColorScheme.light(
          primary: AppColors.dustyTeal,
          onPrimary: AppColors.pureWhite,
          secondary: AppColors.sageGreen,
          onSecondary: AppColors.pureWhite,
          tertiary: AppColors.warmAmber,
          onTertiary: AppColors.pureWhite,
          surface: AppColors.pureWhite,
          onSurface: AppColors.textDark,
          surfaceContainerLowest: Color(0xFFFBFAF7),
          surfaceContainerLow: Color(0xFFF5F3EE),
          surfaceContainer: AppColors.pureWhite,
          surfaceContainerHigh: AppColors.surfaceElevated,
          surfaceContainerHighest: Color(0xFFE8E5DF),
          error: AppColors.mutedTerra,
          onError: AppColors.pureWhite,
          outline: AppColors.borderLight,
          outlineVariant: AppColors.surfaceElevated,
        ),

        // ── AppBar ─────────────────────────────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.boneWhite,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: 'Sora',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.3,
          ),
        ),

        // ── Cards ─────────────────────────────────────────────────────────
        cardTheme: CardThemeData(
          color: AppColors.pureWhite,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
        ),

        // ── FAB ───────────────────────────────────────────────────────────
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.dustyTeal,
          foregroundColor: AppColors.pureWhite,
          shape: CircleBorder(),
          sizeConstraints: BoxConstraints.tightFor(width: 64, height: 64),
          iconSize: 28,
          elevation: 4,
          focusElevation: 4,
          hoverElevation: 4,
          highlightElevation: 6,
        ),

        // ── ElevatedButton ────────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.dustyTeal,
            foregroundColor: AppColors.pureWhite,
            disabledBackgroundColor: AppColors.surfaceElevated,
            disabledForegroundColor: AppColors.textSubtle,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // ── OutlinedButton ────────────────────────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.dustyTeal,
            side: const BorderSide(color: AppColors.dustyTeal, width: 1.5),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // ── TextButton ────────────────────────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.dustyTeal,
            textStyle: const TextStyle(
              fontFamily: 'Sora',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),

        // ── Inputs ────────────────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.pureWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.dustyTeal, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.mutedTerra, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.mutedTerra, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          labelStyle: const TextStyle(
            fontFamily: 'Sora',
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: const TextStyle(
            fontFamily: 'Sora',
            color: AppColors.textSubtle,
            fontWeight: FontWeight.w400,
          ),
        ),

        // ── Chips ─────────────────────────────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.pureWhite,
          selectedColor: AppColors.dustyTeal,
          labelStyle: const TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.textDark,
          ),
          secondaryLabelStyle: const TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.pureWhite,
          ),
          side: const BorderSide(color: AppColors.borderLight, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),

        // ── Switch ───────────────────────────────────────────────────────
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.pureWhite : AppColors.borderMedium,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.dustyTeal : AppColors.surfaceElevated,
          ),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),

        // ── SegmentedButton ──────────────────────────────────────────────
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: AppColors.surfaceElevated,
            selectedBackgroundColor: AppColors.dustyTeal,
            selectedForegroundColor: AppColors.pureWhite,
            foregroundColor: AppColors.textMuted,
            side: BorderSide.none,
            textStyle: const TextStyle(
              fontFamily: 'Sora',
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        // ── ProgressIndicator ────────────────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.dustyTeal,
        ),

        // ── Divider ──────────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: AppColors.borderLight,
          thickness: 1,
        ),

        // ── BottomSheet ──────────────────────────────────────────────────
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          showDragHandle: true,
          dragHandleColor: AppColors.borderMedium,
        ),

        // ── Dialog ───────────────────────────────────────────────────────
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.pureWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          shadowColor: const Color(0x14000000),
          titleTextStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.2,
          ),
          contentTextStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.6,
          ),
        ),

        // ── Text ─────────────────────────────────────────────────────────
        textTheme: _buildTextTheme(AppColors.textDark, AppColors.textMuted),
      );

  // ── DARK THEME ───────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        fontFamily: 'Sora',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.dustyTeal,
          onPrimary: AppColors.pureWhite,
          secondary: AppColors.sageGreen,
          onSecondary: AppColors.darkBg,
          tertiary: AppColors.warmAmber,
          onTertiary: AppColors.darkBg,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkText,
          surfaceContainerLowest: Color(0xFF181E23),
          surfaceContainerLow: Color(0xFF1E252C),
          surfaceContainer: AppColors.darkSurface,
          surfaceContainerHigh: AppColors.darkSurfaceHigh,
          surfaceContainerHighest: Color(0xFF354048),
          error: AppColors.mutedTerra,
          onError: AppColors.pureWhite,
          outline: AppColors.darkBorderColor,
          outlineVariant: AppColors.darkSurfaceHigh,
        ),

        // ── AppBar ─────────────────────────────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBg,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Sora',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
            letterSpacing: -0.3,
          ),
        ),

        // ── Cards ─────────────────────────────────────────────────────────
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.darkBorderColor, width: 1),
          ),
        ),

        // ── FAB ───────────────────────────────────────────────────────────
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.dustyTeal,
          foregroundColor: AppColors.pureWhite,
          shape: CircleBorder(),
          sizeConstraints: BoxConstraints.tightFor(width: 64, height: 64),
          iconSize: 28,
          elevation: 4,
          focusElevation: 4,
          hoverElevation: 4,
          highlightElevation: 6,
        ),

        // ── ElevatedButton ────────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.dustyTeal,
            foregroundColor: AppColors.pureWhite,
            disabledBackgroundColor: AppColors.darkSurfaceHigh,
            disabledForegroundColor: AppColors.darkTextMuted,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // ── OutlinedButton ────────────────────────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.dustyTeal,
            side: const BorderSide(color: AppColors.dustyTeal, width: 1.5),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // ── TextButton ────────────────────────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.dustyTeal,
            textStyle: const TextStyle(
              fontFamily: 'Sora',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),

        // ── Inputs ────────────────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.darkBorderColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.darkBorderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.dustyTeal, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.mutedTerra, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.mutedTerra, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          labelStyle: const TextStyle(
            fontFamily: 'Sora',
            color: AppColors.darkTextMuted,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            fontFamily: 'Sora',
            color: AppColors.darkTextMuted.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
          ),
        ),

        // ── Chips ─────────────────────────────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedColor: AppColors.dustyTeal,
          labelStyle: const TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.darkText,
          ),
          secondaryLabelStyle: const TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.pureWhite,
          ),
          side: const BorderSide(color: AppColors.darkBorderColor, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),

        // ── Switch ───────────────────────────────────────────────────────
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.darkBg : AppColors.darkBorderColor,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.dustyTeal : AppColors.darkSurfaceHigh,
          ),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),

        // ── SegmentedButton ──────────────────────────────────────────────
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: AppColors.darkSurfaceHigh,
            selectedBackgroundColor: AppColors.dustyTeal,
            selectedForegroundColor: AppColors.pureWhite,
            foregroundColor: AppColors.darkTextMuted,
            side: BorderSide.none,
            textStyle: const TextStyle(
              fontFamily: 'Sora',
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        // ── ProgressIndicator ────────────────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.dustyTeal,
        ),

        // ── Divider ──────────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorderColor,
          thickness: 1,
        ),

        // ── BottomSheet ──────────────────────────────────────────────────
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          showDragHandle: true,
          dragHandleColor: AppColors.darkBorderColor,
        ),

        // ── Dialog ───────────────────────────────────────────────────────
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.darkBorderColor, width: 1),
          ),
          titleTextStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
            letterSpacing: -0.2,
          ),
          contentTextStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            color: AppColors.darkTextMuted,
            height: 1.6,
          ),
        ),

        // ── Text ─────────────────────────────────────────────────────────
        textTheme: _buildTextTheme(AppColors.darkText, AppColors.darkTextMuted),
      );

  static TextTheme _buildTextTheme(Color primary, Color muted) => TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Sora', fontSize: 56, fontWeight: FontWeight.w800,
          color: primary, letterSpacing: -2, height: 1.1,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Sora', fontSize: 44, fontWeight: FontWeight.w800,
          color: primary, letterSpacing: -1.5, height: 1.1,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Sora', fontSize: 36, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -1, height: 1.15,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Sora', fontSize: 30, fontWeight: FontWeight.w700,
          color: primary, letterSpacing: -0.5, height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Sora', fontSize: 24, fontWeight: FontWeight.w700,
          color: primary, height: 1.25,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Sora', fontSize: 20, fontWeight: FontWeight.w600,
          color: primary, height: 1.3,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.w600,
          color: primary, height: 1.35,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Sora', fontSize: 15, fontWeight: FontWeight.w600,
          color: primary, height: 1.4,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Sora', fontSize: 13, fontWeight: FontWeight.w600,
          color: primary, height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Sora', fontSize: 16, fontWeight: FontWeight.w400,
          color: primary, height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Sora', fontSize: 14, fontWeight: FontWeight.w400,
          color: primary, height: 1.6,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Sora', fontSize: 12, fontWeight: FontWeight.w400,
          color: muted, height: 1.55,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Sora', fontSize: 13, fontWeight: FontWeight.w600,
          color: primary, letterSpacing: 0.3, height: 1.4,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Sora', fontSize: 11, fontWeight: FontWeight.w600,
          color: muted, letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Sora', fontSize: 10, fontWeight: FontWeight.w600,
          color: muted, letterSpacing: 0.8,
        ),
      );
}
