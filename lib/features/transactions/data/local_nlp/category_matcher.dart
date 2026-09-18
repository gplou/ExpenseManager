import 'package:expense_manager/features/transactions/domain/transaction_categories.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'keyword_matcher.dart';

/// Guesses a category from keywords across the app's 4 locales, matched
/// against the fixed Spanish category vocabulary in [TransactionCategories]
/// (the same set the DB and the old AI prompt used). Falls back to "Otros"
/// when nothing matches.
class CategoryMatcher {
  const CategoryMatcher._();

  /// Keyed by the Spanish DB category name. Keywords for all 4 locales are
  /// combined per category — voice/receipt text is only ever in one
  /// language at a time, so cross-locale collisions aren't a real risk for
  /// these short, distinct trigger words.
  static const _keywords = <String, List<String>>{
    'Comida': [
      'comida', 'restaurante', 'café', 'cafe', 'supermercado', 'almuerzo',
      'cena', 'desayuno', 'bar', 'pizza', 'comprado comida',
      'food', 'restaurant', 'coffee', 'lunch', 'dinner', 'breakfast',
      'groceries', 'supermarket',
      'nourriture', 'déjeuner', 'dejeuner', 'dîner', 'diner',
      'petit-déjeuner', 'petit dejeuner', 'supermarché', 'supermarche',
      'essen', 'mittagessen', 'abendessen', 'frühstück', 'fruhstuck',
      'supermarkt',
    ],
    'Transporte': [
      'transporte', 'taxi', 'uber', 'gasolina', 'gasolinera', 'autobús',
      'autobus', 'metro', 'tren', 'parking', 'peaje', 'cercanías', 'cercanias',
      'transport', 'gas', 'fuel', 'bus', 'train', 'subway', 'toll',
      'essence', 'métro', 'péage', 'peage',
      'tanken', 'benzin', 'zug', 'u-bahn', 'parkplatz', 'maut',
    ],
    'Vivienda': [
      'alquiler', 'hipoteca', 'vivienda', 'renta', 'luz', 'electricidad',
      'factura de agua', 'factura del gas', 'wifi',
      'rent', 'mortgage', 'housing', 'electricity', 'water bill',
      'internet bill',
      'loyer', 'hypothèque', 'hypotheque', 'logement', 'électricité',
      'electricite', "facture d'eau", 'facture eau',
      'miete', 'hypothek', 'wohnung', 'strom', 'wasserrechnung',
    ],
    'Ocio': [
      'cine', 'netflix', 'spotify', 'videojuego', 'videojuegos', 'concierto',
      'ocio', 'fiesta', 'copas', 'entradas',
      'cinema', 'movie', 'game', 'games', 'concert', 'party', 'leisure',
      'tickets',
      'cinéma', 'film', 'jeu', 'jeux', 'concert', 'fête', 'fete', 'loisir',
      'billets',
      'kino', 'spiel', 'spiele', 'konzert', 'freizeit', 'karten',
    ],
    'Salud': [
      'farmacia', 'médico', 'medico', 'doctor', 'hospital', 'dentista',
      'salud', 'medicina', 'seguro médico', 'seguro medico',
      'pharmacy', 'hospital', 'dentist', 'health', 'medicine',
      'pharmacie', 'médecin', 'medecin', 'docteur', 'hôpital', 'hopital',
      'dentiste', 'santé', 'sante',
      'apotheke', 'arzt', 'krankenhaus', 'zahnarzt', 'gesundheit', 'medizin',
    ],
    'Educación': [
      'curso', 'universidad', 'colegio', 'escuela', 'libro', 'libros',
      'matrícula', 'matricula', 'educación', 'educacion',
      'course', 'university', 'school', 'book', 'books', 'tuition',
      'education',
      'cours', 'université', 'universite', 'école', 'ecole', 'livre',
      'livres', 'scolarité', 'scolarite', 'éducation',
      'kurs', 'universität', 'universitat', 'schule', 'buch', 'bücher',
      'bucher', 'bildung', 'studiengebühren', 'studiengebuhren',
    ],
    'Ropa': [
      'ropa', 'zapatos', 'camisa', 'pantalón', 'pantalon', 'tienda de ropa',
      'clothes', 'clothing', 'shoes', 'shirt', 'pants',
      'vêtements', 'vetements', 'chaussures', 'chemise',
      'kleidung', 'schuhe', 'hemd', 'hose',
    ],
    'Tecnología': [
      'tecnología', 'tecnologia', 'móvil', 'movil', 'ordenador', 'portátil',
      'portatil', 'electrónica', 'electronica', 'cargador',
      'technology', 'phone', 'laptop', 'computer', 'electronics', 'charger',
      'technologie', 'téléphone', 'telephone', 'ordinateur', 'électronique',
      'electronique', 'chargeur',
      'handy', 'elektronik', 'ladegerät', 'ladegerat',
    ],
    'Salario': [
      'salario', 'sueldo', 'nómina', 'nomina',
      'salary', 'paycheck', 'payroll',
      'salaire', 'paie',
      'gehalt', 'lohn',
    ],
    'Freelance': [
      'freelance', 'autónomo', 'autonomo', 'factura cliente',
      'client invoice',
      'facture client',
      'rechnung kunde',
    ],
    'Inversión': [
      'inversión', 'inversion', 'dividendo', 'acciones', 'bolsa',
      'investment', 'dividend', 'stocks',
      'investissement', 'dividende', 'actions',
      'investition', 'dividende', 'aktien',
    ],
    'Regalo': [
      'regalo', 'regalos',
      'gift', 'present',
      'cadeau',
      'geschenk',
    ],
  };

  static String match(String text, TransactionType type) {
    final lower = text.toLowerCase();
    for (final category in TransactionCategories.forType(type)) {
      final keywords = _keywords[category.name];
      if (keywords == null) continue;
      if (KeywordMatcher.containsAnyWord(lower, keywords)) return category.name;
    }
    return 'Otros';
  }
}
