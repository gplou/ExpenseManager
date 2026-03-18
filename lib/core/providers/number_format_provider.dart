import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kNumberFormatKey = 'number_format_style';

enum NumberFormatStyle {
  /// Decimal separator = dot, thousands = comma  →  1,234.56
  dotDecimal,

  /// Decimal separator = comma, thousands = dot  →  1.234,56
  commaDecimal,
}

/// Formats [value] with thousands separator and [decimals] decimal places
/// according to [style].
///
/// Examples:
///   formatAmount(1234.5, NumberFormatStyle.dotDecimal)    → "1,234.50"
///   formatAmount(1234.5, NumberFormatStyle.commaDecimal)  → "1.234,50"
String formatAmount(
  double value,
  NumberFormatStyle style, {
  int decimals = 2,
}) {
  final isNeg = value < 0;
  final abs = value.abs();

  final raw = abs.toStringAsFixed(decimals);
  final dotIndex = raw.indexOf('.');
  final intPart = dotIndex == -1 ? raw : raw.substring(0, dotIndex);
  final decPart = dotIndex == -1 ? '' : raw.substring(dotIndex + 1);

  final thousandsSep = style == NumberFormatStyle.dotDecimal ? ',' : '.';
  final decimalSep = style == NumberFormatStyle.dotDecimal ? '.' : ',';

  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) {
      buf.write(thousandsSep);
    }
    buf.write(intPart[i]);
  }

  if (decimals > 0) {
    buf.write(decimalSep);
    buf.write(decPart);
  }

  return '${isNeg ? '-' : ''}$buf';
}

class NumberFormatNotifier extends AsyncNotifier<NumberFormatStyle> {
  @override
  Future<NumberFormatStyle> build() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_kNumberFormatKey);
    return val == NumberFormatStyle.commaDecimal.name
        ? NumberFormatStyle.commaDecimal
        : NumberFormatStyle.dotDecimal;
  }

  Future<void> setStyle(NumberFormatStyle style) async {
    state = AsyncData(style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNumberFormatKey, style.name);
  }
}

final numberFormatProvider =
    AsyncNotifierProvider<NumberFormatNotifier, NumberFormatStyle>(
  NumberFormatNotifier.new,
);
