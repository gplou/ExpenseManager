import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2563EB);       // Azul vibrante
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color secondary = Color(0xFF7C3AED);     // Violeta acento
  static const Color secondaryLight = Color(0xFFA78BFA);

  // Semánticos
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Light mode
  static const Color backgroundLight = Color(0xFFF8FAFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Dark mode
  static const Color backgroundDark = Color(0xFF111111);
  static const Color surfaceDark = Color(0xFF1C1C1C);
  static const Color borderDark = Color(0xFF2A2A2A);
  static const Color textPrimaryDark = Color(0xFFF0F0F0);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);

  // Prioridades de tareas
  static const Color priorityHigh = Color(0xFFEF4444);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityLow = Color(0xFF10B981);
}
