import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  // ── plaintext → encrypted migration: user_version carry-over ─────────────
  //
  // Regression for EXPENSE-MANAGER-7: sqlcipher_export() copies schema + data
  // but NOT the user_version pragma. If the migrated DB is reopened with
  // version 3 while its user_version is still 0, sqflite treats it as brand new
  // and runs onCreate → createSchema → "table transactions already exists".
  // These tests stand in for SQLCipher (unavailable in the FFI host VM) by
  // copying a fully-formed schema into a fresh file and reopening it through
  // the production onCreate/onUpgrade callbacks.

  group('migrated DB reopen', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('em_migration_test');
    });

    tearDown(() async {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    });

    /// Reopens [path] through the production callbacks (`onCreate` /
    /// `applyUpgrades`), returning which path ran:
    ///   - `created` when onCreate built a fresh schema
    ///   - `upgradedFrom` when onUpgrade ran (the value is oldVersion)
    /// onCreate also self-heals a broken-migration DB without recreating tables.
    Future<({bool created, int? upgradedFrom})> reopenLikeProduction(
      String path,
    ) async {
      var created = false;
      int? upgradedFrom;
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            // Mirror production: onCreate self-heals already-populated DBs.
            created = !await _hasTable(db, 'transactions');
            await LocalDatabase.onCreate(db, version);
          },
          onUpgrade: (db, oldV, newV) async {
            upgradedFrom = oldV;
            await LocalDatabase.applyUpgrades(db, oldV, newV);
          },
        ),
      );
      await db.close();
      return (created: created, upgradedFrom: upgradedFrom);
    }

    test('self-heals a migrated DB left at user_version 0 (no crash)', () async {
      final path = p.join(tmpDir.path, 'migrated_v0.db');
      // Reproduce sqlcipher_export's defect: full schema + data, but the
      // user_version pragma was never carried across, so it defaults to 0.
      // This is the exact on-disk state already shipped to crashing users.
      final src = await databaseFactoryFfi.openDatabase(path);
      await LocalDatabase.createSchema(src);
      await src.insert('transactions', {
        'id': 'stranded',
        'user_id': 'u',
        'amount': 4.0,
        'type': 'expense',
        'category': 'C',
        'date': '2026-01-01',
        'created_at': '2026-01-01T00:00:00Z',
        'currency': 'EUR',
      });
      await src.execute('PRAGMA user_version = 0');
      await src.close();

      // openDatabase(version: 3) sees version 0 → onCreate. Before the heal this
      // crashed with "table transactions already exists"; now it recovers.
      final result = await reopenLikeProduction(path);
      expect(result.created, isFalse,
          reason: 'must not recreate tables on a populated DB');

      // No data lost, and the missing table was filled in by the heal.
      final db = await databaseFactoryFfi.openDatabase(path);
      expect(await _hasTable(db, 'pending_operations'), isTrue);
      final rows = await db.query('transactions');
      expect(rows.single['id'], 'stranded');
      await db.close();
    });

    test('carrying user_version across the export takes the upgrade path',
        () async {
      final path = p.join(tmpDir.path, 'migrated_v3.db');
      final src = await databaseFactoryFfi.openDatabase(path);
      await LocalDatabase.createSchema(src);
      await src.insert('transactions', {
        'id': 'pre-migration',
        'user_id': 'u',
        'amount': 9.0,
        'type': 'expense',
        'category': 'C',
        'date': '2026-01-01',
        'created_at': '2026-01-01T00:00:00Z',
        'currency': 'EUR',
      });
      // The fix: the migration now copies the source user_version onto the
      // encrypted file. The source schema is current (v3), so set 3.
      await src.execute('PRAGMA user_version = 3');
      await src.close();

      // Reopening must NOT crash and must NOT run onCreate; v3→v3 is a no-op.
      final result = await reopenLikeProduction(path);
      expect(result.created, isFalse);
      expect(result.upgradedFrom, isNull,
          reason: 'v3 → v3 should not call onUpgrade');

      // Existing data survived the reopen.
      final db = await databaseFactoryFfi.openDatabase(path);
      final rows = await db.query('transactions');
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'pre-migration');
      await db.close();
    });

    test('carrying a pre-v3 user_version runs the incremental upgrade',
        () async {
      final path = p.join(tmpDir.path, 'migrated_v1.db');
      // A v1 plaintext DB (no pending_operations) carried across as version 1.
      final src = await databaseFactoryFfi.openDatabase(path);
      await _createV1Schema(src);
      await src.execute('PRAGMA user_version = 1');
      await src.close();

      final result = await reopenLikeProduction(path);
      expect(result.upgradedFrom, 1,
          reason: 'v1 → v3 should run onUpgrade from 1');

      // onUpgrade added the missing table and set the hydration-reset flag.
      final db = await databaseFactoryFfi.openDatabase(path);
      expect(await _hasTable(db, 'pending_operations'), isTrue);
      await db.close();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(LocalDatabase.needsHydrationResetKey), isTrue);
    });

    test('onCreate builds a full fresh schema for a brand-new DB', () async {
      final path = p.join(tmpDir.path, 'fresh.db');
      final result = await reopenLikeProduction(path);
      expect(result.created, isTrue);
      expect(result.upgradedFrom, isNull);

      final db = await databaseFactoryFfi.openDatabase(path);
      expect(await _hasTable(db, 'transactions'), isTrue);
      expect(await _hasTable(db, 'recurring_transactions'), isTrue);
      expect(await _hasTable(db, 'pending_operations'), isTrue);
      await db.close();
    });
  });
}
