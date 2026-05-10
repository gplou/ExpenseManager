import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'transaction_model.dart';

class TransactionCategory {
  const TransactionCategory({
    required this.name,
    required this.icon,
    this.emojiOverride,
  });

  final String name;
  final IconData icon;
  /// Set for emoji-based custom categories; null for built-in Material icon categories.
  final String? emojiOverride;
}

class TransactionCategories {
  TransactionCategories._();

  /// Fixed set of icons the user can pick for custom categories.
  /// Stored as const values so tree-shaking works in release builds.
  static const List<IconData> pickableIcons = [
    Icons.sports_soccer_outlined,
    Icons.fitness_center_outlined,
    Icons.directions_bike_outlined,
    Icons.flight_outlined,
    Icons.hotel_outlined,
    Icons.local_cafe_outlined,
    Icons.local_bar_outlined,
    Icons.movie_outlined,
    Icons.music_note_outlined,
    Icons.book_outlined,
    Icons.local_pharmacy_outlined,
    Icons.spa_outlined,
    Icons.pets_outlined,
    Icons.child_care_outlined,
    Icons.shopping_cart_outlined,
    Icons.local_gas_station_outlined,
    Icons.directions_bus_outlined,
    Icons.handyman_outlined,
    Icons.park_outlined,
    Icons.beach_access_outlined,
    Icons.savings_outlined,
    Icons.card_membership_outlined,
    Icons.volunteer_activism_outlined,
    Icons.subscriptions_outlined,
  ];

  static const List<TransactionCategory> income = [
    TransactionCategory(name: 'Salario', icon: Icons.work_outline),
    TransactionCategory(name: 'Freelance', icon: Icons.laptop_outlined),
    TransactionCategory(name: 'Inversión', icon: Icons.trending_up_outlined),
    TransactionCategory(name: 'Regalo', icon: Icons.card_giftcard_outlined),
    TransactionCategory(name: 'Otros', icon: Icons.attach_money),
  ];

  static const List<TransactionCategory> expense = [
    TransactionCategory(name: 'Comida', icon: Icons.restaurant_outlined),
    TransactionCategory(name: 'Transporte', icon: Icons.directions_car_outlined),
    TransactionCategory(name: 'Vivienda', icon: Icons.home_outlined),
    TransactionCategory(name: 'Ocio', icon: Icons.sports_esports_outlined),
    TransactionCategory(name: 'Salud', icon: Icons.favorite_outline),
    TransactionCategory(name: 'Educación', icon: Icons.school_outlined),
    TransactionCategory(name: 'Ropa', icon: Icons.checkroom_outlined),
    TransactionCategory(name: 'Tecnología', icon: Icons.devices_outlined),
    TransactionCategory(name: 'Otros', icon: Icons.shopping_bag_outlined),
  ];

  static List<TransactionCategory> forType(TransactionType type) =>
      type.isIncome ? income : expense;

  /// Cached icon maps for O(1) lookup instead of O(n) firstWhere.
  static Map<String, IconData>? _incomeIconCache;
  static Map<String, IconData>? _expenseIconCache;

  static Map<String, IconData> _buildIconMap(List<TransactionCategory> cats) =>
      {for (final c in cats) c.name: c.icon};

  static IconData iconFor(String categoryName, TransactionType type,
      {List<TransactionCategory> extra = const []}) {
    if (extra.isEmpty) {
      // Use cached map for built-in categories
      final cache = type.isIncome
          ? (_incomeIconCache ??= _buildIconMap(income))
          : (_expenseIconCache ??= _buildIconMap(expense));
      return cache[categoryName] ?? Icons.label_outlined;
    }
    // With extra categories, build a merged map
    final categories = [...forType(type), ...extra];
    final map = _buildIconMap(categories);
    return map[categoryName] ?? Icons.label_outlined;
  }

  /// Map of DB keys to localization functions.
  /// Adding a new built-in category only requires adding an entry here.
  static final _localizers = <String, String Function(AppLocalizations)>{
    'Salario': (l) => l.categorySalary,
    'Freelance': (l) => l.categoryFreelance,
    'Inversión': (l) => l.categoryInvestment,
    'Regalo': (l) => l.categoryGift,
    'Comida': (l) => l.categoryFood,
    'Transporte': (l) => l.categoryTransport,
    'Vivienda': (l) => l.categoryHousing,
    'Ocio': (l) => l.categoryLeisure,
    'Salud': (l) => l.categoryHealth,
    'Educación': (l) => l.categoryEducation,
    'Ropa': (l) => l.categoryClothing,
    'Tecnología': (l) => l.categoryTechnology,
    'Otros': (l) => l.categoryOther,
  };

  /// Returns the localized display name for a DB category key.
  /// DB keys stay in Spanish; only the UI label is translated.
  /// Custom categories (unknown keys) are returned as-is.
  static String localizedName(String dbKey, AppLocalizations l10n) =>
      _localizers[dbKey]?.call(l10n) ?? dbKey;

  /// Map of DB keys to emoji representations.
  static const _emojis = <String, String>{
    'Salario': '💼',
    'Freelance': '💻',
    'Inversión': '📈',
    'Regalo': '🎁',
    'Comida': '🍕',
    'Transporte': '🚗',
    'Vivienda': '🏠',
    'Ocio': '🎮',
    'Salud': '💊',
    'Educación': '📚',
    'Ropa': '👕',
    'Tecnología': '⚡',
  };

  /// Returns the emoji for a built-in DB category key.
  static String emojiFor(String dbKey, {bool isIncome = false}) =>
      _emojis[dbKey] ?? (isIncome ? '💰' : '💸');

  /// Resolves an emoji honoring user overrides on custom categories,
  /// falling back to [emojiFor] for built-ins.
  static String resolveEmoji(
    String name,
    bool isIncome,
    List<TransactionCategory> custom,
  ) {
    final c = custom.where((c) => c.name == name).firstOrNull;
    if (c?.emojiOverride != null) return c!.emojiOverride!;
    return emojiFor(name, isIncome: isIncome);
  }
}
