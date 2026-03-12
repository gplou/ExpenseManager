import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCurrencyKey = 'currency_code';

class AppCurrency {
  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
  });

  final String code;
  final String symbol;
  final String name;
  final String flag;
}

const supportedCurrencies = [
  AppCurrency(code: 'EUR', symbol: '€', name: 'Euro', flag: '🇪🇺'),
  AppCurrency(code: 'USD', symbol: '\$', name: 'US Dollar', flag: '🇺🇸'),
  AppCurrency(code: 'GBP', symbol: '£', name: 'British Pound', flag: '🇬🇧'),
  AppCurrency(code: 'JPY', symbol: '¥', name: 'Japanese Yen', flag: '🇯🇵'),
  AppCurrency(code: 'CHF', symbol: 'Fr', name: 'Swiss Franc', flag: '🇨🇭'),
  AppCurrency(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar', flag: '🇨🇦'),
  AppCurrency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', flag: '🇦🇺'),
  AppCurrency(code: 'MXN', symbol: 'MX\$', name: 'Mexican Peso', flag: '🇲🇽'),
  AppCurrency(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', flag: '🇧🇷'),
  AppCurrency(code: 'COP', symbol: '\$', name: 'Colombian Peso', flag: '🇨🇴'),
  AppCurrency(code: 'SEK', symbol: 'kr', name: 'Swedish Krona', flag: '🇸🇪'),
  AppCurrency(code: 'NOK', symbol: 'kr', name: 'Norwegian Krone', flag: '🇳🇴'),
  AppCurrency(code: 'DKK', symbol: 'kr', name: 'Danish Krone', flag: '🇩🇰'),
  AppCurrency(code: 'PLN', symbol: 'zł', name: 'Polish Zloty', flag: '🇵🇱'),
  AppCurrency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', flag: '🇨🇳'),
];

String currencySymbol(String code) => supportedCurrencies
    .firstWhere((c) => c.code == code, orElse: () => supportedCurrencies.first)
    .symbol;

class CurrencyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrencyKey) ?? 'EUR';
  }

  Future<void> setCurrency(String code) async {
    state = AsyncData(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrencyKey, code);
  }
}

final currencyProvider =
    AsyncNotifierProvider<CurrencyNotifier, String>(CurrencyNotifier.new);
