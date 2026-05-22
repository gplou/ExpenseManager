import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';

/// Builds a v1 schema (no `pending_operations` table) so we can exercise
/// every branch of [LocalDatabase.applyUpgrades].
Future<void> _createV1Schema(Database db) async {
  await db.execute('''
    CREATE TABLE transactions (
      id   TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      amount REAL NOT NULL,
      type TEXT NOT NULL,
      category TEXT NOT NULL,
      date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      currency TEXT NOT NULL DEFAULT 'EUR'
    )
  ''');
  await db.execute('''
    CREATE TABLE recurring_transactions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      amount REAL NOT NULL,
      type TEXT NOT NULL,
      category TEXT NOT NULL,
      recurrence_type TEXT NOT NULL,
      next_occurrence TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
}

/// Builds a v2 schema (transactions + recurring + pending_operations) so we
/// can verify the v2→v3 hop runs the hydration-reset flag without touching
/// the existing pending_operations table.
Future<void> _createV2Schema(Database db) async {
  await _createV1Schema(db);
  await db.execute('''
    CREATE TABLE pending_operations (
      id         TEXT    PRIMARY KEY,
      user_id    TEXT    NOT NULL,
      op_type    TEXT    NOT NULL,
      entity_id  TEXT    NOT NULL,
      payload    TEXT,
      created_at TEXT    NOT NULL,
      attempts   INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

Future<bool> _hasTable(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    [table],
  );
  return rows.isNotEmpty;
}

void main() {
  sqfliteFfiInit();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── createSchema ─────────────────────────────────────────────────────────

  group('createSchema', () {
    test('creates all v3 tables + indexes', () async {
      final db = await databaseFactoryFfi.openDatabase(':memory:');
      await LocalDatabase.createSchema(db);

      expect(await _hasTable(db, 'transactions'), isTrue);
      expect(await _hasTable(db, 'recurring_transactions'), isTrue);
      expect(await _hasTable(db, 'pending_operations'), isTrue);

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'",
      );
      final names = indexes.map((r) => r['name']).toSet();
      expect(names, contains('idx_transactions_user_date'));
      expect(names, contains('idx_recurring_user'));
      expect(names, contains('idx_pending_user'));

      await db.close();
    });
  });

  // ── applyUpgrades — v1 → v3 ──────────────────────────────────────────────

  group('applyUpgrades v1 → v3', () {
    test('adds pending_operations table and sets hydration-reset flag', () async {
      final db = await databaseFactoryFfi.openDatabase(':memory:');
      await _createV1Schema(db);
      expect(await _hasTable(db, 'pending_operations'), isFalse);

      await LocalDatabase.applyUpgrades(db, 1, 3);

      expect(await _hasTable(db, 'pending_operations'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(LocalDatabase.needsHydrationResetKey), isTrue);

      await db.close();
    });

    test('preserves existing data in transactions table', () async {
      final db = await databaseFactoryFfi.openDatabase(':memory:');
      await _createV1Schema(db);
      await db.insert('transactions', {
        'id': 'pre-upgrade',
        'user_id': 'u',
        'amount': 5.0,
        'type': 'expense',
        'category': 'C',
        'date': '2026-01-01',
        'created_at': '2026-01-01T00:00:00Z',
        'currency': 'EUR',
      });

      await LocalDatabase.applyUpgrades(db, 1, 3);

      final rows = await db.query('transactions');
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'pre-upgrade');

      await db.close();
    });
  });

  // ── applyUpgrades — v2 → v3 ──────────────────────────────────────────────

  group('applyUpgrades v2 → v3', () {
    test('sets the hydration-reset flag without recreating pending_operations',
        () async {
      final db = await databaseFactoryFfi.openDatabase(':memory:');
      await _createV2Schema(db);
      await db.insert('pending_operations', {
        'id': 'op-1',
        'user_id': 'u',
        'op_type': 'create',
        'entity_id': 'tx-1',
        'payload': '{}',
        'created_at': '2026-01-01T00:00:00Z',
        'attempts': 0,
      });

      await LocalDatabase.applyUpgrades(db, 2, 3);

      // Existing rows are preserved (CREATE TABLE IF NOT EXISTS was a no-op).
      final ops = await db.query('pending_operations');
      expect(ops, hasLength(1));
      expect(ops.single['id'], 'op-1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(LocalDatabase.needsHydrationResetKey), isTrue);

      await db.close();
    });
  });

  // ── applyUpgrades — no-op at v3 ──────────────────────────────────────────

  group('applyUpgrades v3 → v3', () {
    test('is a no-op and does not touch SharedPreferences', () async {
      final db = await databaseFactoryFfi.openDatabase(':memory:');
      await LocalDatabase.createSchema(db);

      await LocalDatabase.applyUpgrades(db, 3, 3);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(LocalDatabase.needsHydrationResetKey), isNull);

      await db.close();
    });
  });
}
