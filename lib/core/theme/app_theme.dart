import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          error: AppColors.error,
          surface: AppColors.surfaceLight,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        fontFamily: 'Sora',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundLight,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Sora',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: AppColors.surfaceLight,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(
            fontFamily: 'Sora',
            color: AppColors.textSecondaryLight,
          ),
        ),
        textTheme: _buildTextTheme(AppColors.textPrimaryLight),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderLight,
          thickness: 1,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primaryLight,
          secondary: AppColors.secondaryLight,
          error: AppColors.error,
          surface: AppColors.surfaceDark,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        fontFamily: 'Sora',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: AppColors.textPrimaryDark,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: AppColors.surfaceDark,
        ),
        textTheme: _buildTextTheme(AppColors.textPrimaryDark),
      );

  static TextTheme _buildTextTheme(Color primaryColor) => TextTheme(
        displayLarge: TextStyle(
            fontFamily: 'Sora',
            fontSize: 57,
            fontWeight: FontWeight.w700,
            color: primaryColor),
        displayMedium: TextStyle(
            fontFamily: 'Sora',
            fontSize: 45,
            fontWeight: FontWeight.w700,
            color: primaryColor),
        displaySmall: TextStyle(
            fontFamily: 'Sora',
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: primaryColor),
        headlineLarge: TextStyle(
            fontFamily: 'Sora',
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: primaryColor),
        headlineMedium: TextStyle(
            fontFamily: 'Sora',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: primaryColor),
        headlineSmall: TextStyle(
            fontFamily: 'Sora',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: primaryColor),
        titleLarge: TextStyle(
            fontFamily: 'Sora',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: primaryColor),
        titleMedium: TextStyle(
            fontFamily: 'Sora',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: primaryColor),
        titleSmall: TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primaryColor),
        bodyLarge: TextStyle(
            fontFamily: 'Sora', fontSize: 16, color: primaryColor),
        bodyMedium: TextStyle(
            fontFamily: 'Sora', fontSize: 14, color: primaryColor),
        bodySmall:
            TextStyle(fontFamily: 'Sora', fontSize: 12, color: primaryColor),
        labelLarge: TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primaryColor),
      );
}
