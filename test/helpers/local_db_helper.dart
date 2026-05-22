import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';

/// Initialises sqflite for FFI execution in the host VM. Idempotent —
/// safe to call from multiple test files.
void initSqfliteFfi() {
  sqfliteFfiInit();
}

/// Opens an in-memory SQLite database, creates the app schema on it, and
/// wires it into [LocalDatabase.instance] via [LocalDatabase.setTestDb].
///
/// Returns the underlying [Database] so callers can run raw queries
/// if needed.
///
/// Test wiring is automatic when you call this from `setUp`: a matching
/// `tearDown` is registered via [addTearDown] to close the DB and detach
/// it from the singleton.
Future<Database> useInMemoryDatabase() async {
  initSqfliteFfi();
  final db = await databaseFactoryFfi.openDatabase(':memory:');
  await LocalDatabase.createSchema(db);
  LocalDatabase.instance.setTestDb(db);
  addTearDown(() async {
    await LocalDatabase.instance.close();
  });
  return db;
}
