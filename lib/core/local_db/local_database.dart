import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../security/secure_storage.dart';

/// Singleton lazy-open SQLite database, encrypted with SQLCipher.
///
/// On first open the key is generated with [Random.secure] and stored in
/// [SecureStorageService] (Android EncryptedSharedPreferences / iOS Keychain).
/// If a plaintext DB from a previous app version exists it is migrated
/// automatically via SQLCipher's sqlcipher_export() before the key is stored.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  static const _keyStorageKey = 'db_encryption_key';

  /// SharedPreferences key that survives until [InitialSyncService] consumes it.
  /// Set inside [onUpgrade] when crossing from a pre-v3 schema; the in-memory
  /// flag we used before was lost on app restart if hydration didn't run in
  /// the same launch (e.g. user was offline), leaving PRO users with stale
  /// `pro_hydrated_*` flags and an empty local cache forever.
  static const needsHydrationResetKey = 'needs_hydration_reset_v3';

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Injects a pre-opened database. Only for use in tests.
  @visibleForTesting
  void setTestDb(Database db) => _db = db;

  /// Deletes all local data belonging to [userId] across every table.
  /// Does NOT touch rows from other users.
  Future<void> clearUserData(String userId) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete(
        'transactions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'recurring_transactions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'pending_operations',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    });
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'expense_manager.db');

    // flutter_secure_storage can hang indefinitely on some Android devices when
    // the Keystore is initializing (common right after an app update). A 10-second
    // timeout converts a silent hang into a recoverable exception.
    var key = await SecureStorageService.instance
        .read(_keyStorageKey)
        .timeout(const Duration(seconds: 10));
    if (key == null) {
      key = _generateKey();
      // Migrate existing plaintext DB before storing the key so that a crash
      // between writing the key and completing the migration cannot leave the
      // DB in an ambiguous state.
      if (await File(path).exists()) {
        await _migrateToEncrypted(path, key);
      }
      await SecureStorageService.instance.write(_keyStorageKey, key);
    }

    return openDatabase(
      path,
      password: key,
      version: 3,
      onCreate: (db, _) => createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _addPendingOperationsTable(db);
        if (oldVersion < 3) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(needsHydrationResetKey, true);
        }
      },
    );
  }

  static String _generateKey() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
    return base64Url.encode(bytes);
  }

  /// Converts an existing plaintext SQLite file to SQLCipher-encrypted format
  /// using SQLCipher's built-in sqlcipher_export() function, which copies all
  /// pages atomically into a new encrypted file.
  static Future<void> _migrateToEncrypted(String plainPath, String key) async {
    final encPath = '$plainPath.enc';

    // Open the existing plaintext file without a password. SQLCipher treats a
    // missing/empty key as "no encryption", so existing data is accessible.
    final plainDb = await openDatabase(plainPath);
    try {
      await plainDb.execute(
        "ATTACH DATABASE '$encPath' AS encrypted KEY '$key'",
      );
      await plainDb.execute("SELECT sqlcipher_export('encrypted')");
      await plainDb.execute('DETACH DATABASE encrypted');
    } finally {
      await plainDb.close();
    }

    // Atomically swap: remove plaintext file, put encrypted file in its place.
    await File(plainPath).delete();
    await File(encPath).rename(plainPath);
  }

  /// Creates all tables and indexes. Called from [_open] and exposed for
  /// test setup so that in-memory databases have the same schema.
  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id                        TEXT    PRIMARY KEY,
        user_id                   TEXT    NOT NULL,
        amount                    REAL    NOT NULL,
        type                      TEXT    NOT NULL,
        category                  TEXT    NOT NULL,
        subcategory               TEXT,
        description               TEXT,
        date                      TEXT    NOT NULL,
        created_at                TEXT    NOT NULL,
        recurring_transaction_id  TEXT,
        currency                  TEXT    NOT NULL DEFAULT 'EUR'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_transactions_user_date ON transactions(user_id, date)',
    );
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id               TEXT    PRIMARY KEY,
        user_id          TEXT    NOT NULL,
        amount           REAL    NOT NULL,
        type             TEXT    NOT NULL,
        category         TEXT    NOT NULL,
        subcategory      TEXT,
        description      TEXT,
        recurrence_type  TEXT    NOT NULL,
        next_occurrence  TEXT    NOT NULL,
        created_at       TEXT    NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_recurring_user ON recurring_transactions(user_id)',
    );
    await _addPendingOperationsTable(db);
  }

  static Future<void> _addPendingOperationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_operations (
        id         TEXT    PRIMARY KEY,
        user_id    TEXT    NOT NULL,
        op_type    TEXT    NOT NULL,
        entity_id  TEXT    NOT NULL,
        payload    TEXT,
        created_at TEXT    NOT NULL,
        attempts   INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pending_user '
      'ON pending_operations(user_id, created_at)',
    );
  }
}
