import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/providers/locale_provider.dart';
import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

// ── Search query ──────────────────────────────────────────────────────────────

/// Texto de búsqueda del historial. autoDispose: se resetea al salir de la
/// pantalla. El debounce (300ms) vive en el widget, no aquí.
class TransactionSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;

  void clear() => state = '';
}

final transactionSearchQueryProvider =
    NotifierProvider.autoDispose<TransactionSearchQuery, String>(
  TransactionSearchQuery.new,
);

// ── Filtered list (derived from allTransactionsProvider) ─────────────────────

/// Lista del historial con la búsqueda aplicada. Con query vacía devuelve la
/// lista completa sin recorrerla.
final filteredTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  // Watch síncrono antes del await: usar ref tras el gap lanza
  // UnmountedRefException si el provider fue invalidado mientras esperaba.
  final query = ref.watch(transactionSearchQueryProvider);
  final all = await ref.watch(allTransactionsProvider.future);
  if (query.trim().isEmpty) return all;
  if (!ref.mounted) return all;
  // Las categorías se guardan como clave en español en la BD; el usuario busca
  // por el nombre que ve en pantalla, así que resolvemos las l10n del locale
  // activo sin BuildContext.
  final locale = await ref.watch(localeProvider.future);
  final l10n = lookupAppLocalizations(locale);
  return filterTransactionsByQuery(all, query, l10n);
});

/// Filtrado puro (testeable sin contenedor): match case- y acento-insensitive
/// sobre descripción, categoría localizada (y su clave en BD), subcategoría e
/// importe.
List<TransactionModel> filterTransactionsByQuery(
  List<TransactionModel> transactions,
  String query,
  AppLocalizations l10n,
) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return transactions;
  // "12,50" y "12.50" encuentran el mismo importe.
  final amountQuery = q.replaceAll(',', '.');
  return transactions.where((t) {
    final description = t.description;
    if (description != null &&
        normalizeForSearch(description).contains(q)) {
      return true;
    }
    if (normalizeForSearch(TransactionCategories.localizedName(t.category, l10n))
        .contains(q)) {
      return true;
    }
    if (normalizeForSearch(t.category).contains(q)) return true;
    final subcategory = t.subcategory;
    if (subcategory != null && normalizeForSearch(subcategory).contains(q)) {
      return true;
    }
    return t.amount.toStringAsFixed(2).contains(amountQuery);
  }).toList();
}

/// Lowercase + sin acentos latinos comunes, para que "cafe" encuentre "Café".
String normalizeForSearch(String input) {
  var s = input.toLowerCase().trim();
  const replacements = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss',
  };
  for (final entry in replacements.entries) {
    s = s.replaceAll(entry.key, entry.value);
  }
  return s;
}
