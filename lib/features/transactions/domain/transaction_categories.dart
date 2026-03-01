import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'transaction_model.dart';

class TransactionCategory {
  const TransactionCategory({
    required this.name,
    required this.icon,
  });

  final String name;
  final IconData icon;
}

class TransactionCategories {
  TransactionCategories._();

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

  static IconData iconFor(String categoryName, TransactionType type,
      {List<TransactionCategory> extra = const []}) {
    final categories = [...forType(type), ...extra];
    return categories
        .firstWhere(
          (c) => c.name == categoryName,
          orElse: () =>
              const TransactionCategory(name: '', icon: Icons.label_outlined),
        )
        .icon;
  }

  /// Returns the localized display name for a DB category key.
  /// DB keys stay in Spanish; only the UI label is translated.
  /// Custom categories (unknown keys) are returned as-is.
  static String localizedName(String dbKey, AppLocalizations l10n) =>
      switch (dbKey) {
        'Salario' => l10n.categorySalary,
        'Freelance' => l10n.categoryFreelance,
        'Inversión' => l10n.categoryInvestment,
        'Regalo' => l10n.categoryGift,
        'Comida' => l10n.categoryFood,
        'Transporte' => l10n.categoryTransport,
        'Vivienda' => l10n.categoryHousing,
        'Ocio' => l10n.categoryLeisure,
        'Salud' => l10n.categoryHealth,
        'Educación' => l10n.categoryEducation,
        'Ropa' => l10n.categoryClothing,
        'Tecnología' => l10n.categoryTechnology,
        _ => dbKey,
      };
}
