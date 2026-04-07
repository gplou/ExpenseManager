import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton lazy-open SQLite database.
/// PRO users never trigger the open, so there is no startup penalty for them.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

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
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) => createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _addPendingOperationsTable(db);
      },
    );
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
