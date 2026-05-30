import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

// ── String Extensions ──────────────────────────────────────────────────────────

extension StringExtensions on String {
  bool get isValidEmail => RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\.[a-zA-Z]{2,})+$",
  ).hasMatch(this);

  /// Password is valid when it has ≥ 8 characters, at least one letter and one digit.
  bool get isValidPassword {
    if (length < 8) return false;
    final hasLetter = contains(RegExp(r'[a-zA-Z]'));
    final hasDigit = contains(RegExp(r'[0-9]'));
    return hasLetter && hasDigit;
  }

  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String truncate(int maxLength, {String ellipsis = '...'}) =>
      length <= maxLength ? this : '${substring(0, maxLength)}$ellipsis';
}

// ── DateTime Extensions ────────────────────────────────────────────────────────

extension DateTimeExtensions on DateTime {
  String get formattedDate => DateFormat('dd/MM/yyyy').format(this);
  String get formattedDateTime => DateFormat('dd/MM/yyyy HH:mm').format(this);
  String get formattedTime => DateFormat('HH:mm').format(this);

  bool get isToday {
    final now = clock.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = clock.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  bool get isOverdue => isBefore(clock.now());

  String get relativeDate {
    if (isToday) return 'Hoy';
    if (isTomorrow) return 'Mañana';
    if (isOverdue) return 'Vencida';
    return formattedDate;
  }

  String relativeDateL10n(AppLocalizations l10n) {
    if (isToday) return l10n.relToday;
    if (isTomorrow) return l10n.relTomorrow;
    if (isOverdue) return l10n.relOverdue;
    return formattedDate;
  }
}

// ── BuildContext Extensions ────────────────────────────────────────────────────

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  void showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error
            : Theme.of(this).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
