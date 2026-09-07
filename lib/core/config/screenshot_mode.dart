import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/core/utils/app_logger.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

/// ANDAMIAJE TEMPORAL — solo para generar capturas de tienda.
///
/// Se activa con `--dart-define=SCREENSHOT_MODE=true`. Con el flag apagado
/// (el default, y siempre en cualquier build publicable) todo esto es código
/// muerto que el compilador elimina.
///
/// Lo que hace:
///  - desbloquea la UI PRO en el cliente (`isProProvider` → true),
///  - fuerza TODOS los repos a SQLite local y apaga los servicios de sync,
///    para que la cuenta de demo no escriba una sola fila en Supabase,
///  - siembra datos de demo verosímiles en la BD local.
///
/// Borrar este archivo (y sus usos en `main.dart`) cuando termine la tanda.
class ScreenshotMode {
  ScreenshotMode._();

  static const bool enabled = bool.fromEnvironment('SCREENSHOT_MODE');
}

/// Siembra la BD local con datos de demo la primera vez que hay sesión.
/// Idempotente: si el usuario ya tiene transacciones, no toca nada.
///
/// Las pantallas cargan sus datos en paralelo a la siembra, así que al terminar
/// invalidamos los providers de lectura para que relean la BD ya poblada.
final screenshotSeedProvider = FutureProvider<void>((ref) async {
  if (!ScreenshotMode.enabled) return;
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  final seeded = await _seedDemoData(user.id);
  if (!seeded) return;
  ref.invalidate(allTransactionsProvider);
  ref.invalidate(budgetsProvider);
  ref.invalidate(budgetProgressProvider);
});

/// Categorías con presupuesto mensual en la demo.
const _budgetedCategories = {'Comida', 'Ocio', 'Transporte', 'Ropa'};

/// Devuelve `true` si ha insertado datos (falso si ya los había).
Future<bool> _seedDemoData(String userId) async {
  final db = await LocalDatabase.instance.db;

  final existing = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM transactions WHERE user_id = ?',
          [userId],
        ),
      ) ??
      0;
  if (existing > 0) {
    AppLogger.log('[ScreenshotMode] ya hay $existing transacciones — no siembro');
    return false;
  }

  final now = DateTime.now();
  final rnd = Random(20260802); // determinista: misma tanda = mismos números
  final batch = db.batch();
  var seq = 0;

  String id() => 'demo-${(seq++).toString().padLeft(4, '0')}';
  String d(DateTime v) =>
      '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';

  void insert({
    required double amount,
    required String type,
    required String category,
    String? subcategory,
    String? description,
    required DateTime date,
  }) {
    batch.insert('transactions', {
      'id': id(),
      'user_id': userId,
      'amount': amount,
      'type': type,
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'date': d(date),
      'created_at': date.toIso8601String(),
      'recurring_transaction_id': null,
      'currency': 'EUR',
    });
  }

  // ── Gastos recurrentes de cada mes ────────────────────────────────────────
  // (importe base, categoría, descripción, día del mes)
  const monthly = <(double, String, String, int)>[
    (890, 'Vivienda', 'Alquiler', 2),
    (62.40, 'Vivienda', 'Luz y gas', 8),
    (39.99, 'Vivienda', 'Internet y móvil', 11),
    (54.60, 'Transporte', 'Abono transporte', 3),
    (12.99, 'Ocio', 'Netflix', 15),
    (10.99, 'Ocio', 'Spotify', 21),
    (42.50, 'Salud', 'Gimnasio', 5),
  ];

  // ── Gastos variables: se sortean unos cuantos por mes ─────────────────────
  const variable = <(String, String, double, double)>[
    ('Comida', 'Compra semanal', 48, 96),
    ('Comida', 'Supermercado', 22, 65),
    ('Comida', 'Comida fuera', 14, 42),
    ('Comida', 'Café', 2.4, 6.5),
    ('Transporte', 'Gasolina', 45, 78),
    ('Transporte', 'Taxi', 9, 24),
    ('Ocio', 'Cine', 9, 22),
    ('Ocio', 'Cena con amigos', 25, 68),
    ('Ocio', 'Libro', 12, 28),
    ('Ropa', 'Zapatillas', 39, 95),
    ('Ropa', 'Camiseta', 15, 35),
    ('Tecnología', 'Accesorios', 18, 74),
    ('Salud', 'Farmacia', 8, 32),
    ('Educación', 'Curso online', 19, 49),
    ('Otros', 'Regalo cumpleaños', 20, 55),
  ];

  double between(double lo, double hi) =>
      double.parse((lo + rnd.nextDouble() * (hi - lo)).toStringAsFixed(2));

  // 12 meses hacia atrás, incluido el actual.
  for (var back = 11; back >= 0; back--) {
    final month = DateTime(now.year, now.month - back);
    final isCurrentMonth = back == 0;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    // El mes en curso solo se llena hasta hoy.
    final maxDay = isCurrentMonth ? now.day : lastDay;

    // Nómina + algún ingreso extra
    insert(
      amount: 2150 + (rnd.nextInt(3) * 50),
      type: 'income',
      category: 'Salario',
      description: 'Nómina',
      date: DateTime(month.year, month.month, min(28, maxDay)),
    );
    if (rnd.nextInt(3) == 0 && maxDay > 18) {
      insert(
        amount: between(180, 620),
        type: 'income',
        category: 'Freelance',
        description: 'Proyecto web',
        date: DateTime(month.year, month.month, 18),
      );
    }

    for (final (amount, category, description, day) in monthly) {
      if (day > maxDay) continue;
      insert(
        amount: category == 'Vivienda' && description == 'Luz y gas'
            ? between(amount - 18, amount + 24)
            : amount,
        type: 'expense',
        category: category,
        description: description,
        date: DateTime(month.year, month.month, day),
      );
    }

    final count = 14 + rnd.nextInt(8);
    for (var i = 0; i < count; i++) {
      final (category, description, lo, hi) =
          variable[rnd.nextInt(variable.length)];
      insert(
        amount: between(lo, hi),
        type: 'expense',
        category: category,
        description: description,
        date: DateTime(month.year, month.month, 1 + rnd.nextInt(maxDay)),
      );
    }

    // El sorteo puede dejar una categoría con presupuesto a cero; en el mes en
    // curso (el que se ve en el dashboard) forzamos cobertura para que ninguna
    // barra de progreso salga vacía.
    if (isCurrentMonth) {
      for (final (category, description, lo, hi) in variable) {
        if (!_budgetedCategories.contains(category)) continue;
        insert(
          amount: between(lo, hi),
          type: 'expense',
          category: category,
          description: description,
          date: DateTime(month.year, month.month, 1 + rnd.nextInt(maxDay)),
        );
      }
    }
  }

  // ── Recurrentes visibles en la ficha ──────────────────────────────────────
  const recurring = <(double, String, String, String, int)>[
    (890, 'Vivienda', 'Alquiler', 'monthly', 2),
    (12.99, 'Ocio', 'Netflix', 'monthly', 15),
    (42.50, 'Salud', 'Gimnasio', 'monthly', 5),
  ];
  for (final (amount, category, description, type, day) in recurring) {
    final next = DateTime(now.year, now.month, day).isAfter(now)
        ? DateTime(now.year, now.month, day)
        : DateTime(now.year, now.month + 1, day);
    batch.insert('recurring_transactions', {
      'id': id(),
      'user_id': userId,
      'amount': amount,
      'type': 'expense',
      'category': category,
      'subcategory': null,
      'description': description,
      'recurrence_type': type,
      'next_occurrence': d(next),
      'created_at': now.toIso8601String(),
    });
  }

  await batch.commit(noResult: true);

  // ── Presupuestos mensuales ────────────────────────────────────────────────
  // El importe se deriva del gasto REAL del mes en curso para que las barras
  // salgan siempre en un porcentaje presentable, sea día 3 o día 28. Todos por
  // debajo del 80% para no disparar las alertas (que taparían la pantalla con
  // un snackbar durante la captura).
  const targets = <(String, double)>[
    ('Comida', 0.74),
    ('Ocio', 0.52),
    ('Transporte', 0.63),
    ('Ropa', 0.38),
  ];
  final monthStart = d(DateTime(now.year, now.month));
  final monthEnd = d(DateTime(now.year, now.month + 1, 0));
  final budgetBatch = db.batch();
  for (final (category, ratio) in targets) {
    final spent = (await db.rawQuery(
              'SELECT SUM(amount) AS total FROM transactions '
              "WHERE user_id = ? AND type = 'expense' AND category = ? "
              'AND date >= ? AND date <= ?',
              [userId, category, monthStart, monthEnd],
            ))
            .first['total'] as double? ??
        0;
    // Redondeado a la decena superior: los presupuestos reales son cifras
    // redondas, no 187,43 €.
    final amount = max(50.0, (spent / ratio / 10).ceilToDouble() * 10);
    budgetBatch.insert(
      'budgets',
      {
        'id': id(),
        'user_id': userId,
        'category': category,
        'amount': amount,
        'period': 'monthly',
        'currency': 'EUR',
        'created_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  await budgetBatch.commit(noResult: true);
  AppLogger.log('[ScreenshotMode] sembradas $seq filas de demo');
  return true;
}
