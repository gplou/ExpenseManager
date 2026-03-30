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

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'expense_manager.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => createSchema(db),
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
  }
}
