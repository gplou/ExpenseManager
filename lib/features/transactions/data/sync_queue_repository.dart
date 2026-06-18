import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'pending_operation.dart';

/// Gestiona la cola de operaciones pendientes de sincronizar con Supabase.
///
/// Las operaciones se encolan cuando el usuario es PRO y no hay conexión.
/// Se procesan en orden FIFO cuando la conexión se recupera.
class SyncQueueRepository {
  SyncQueueRepository({required this.userId});

  final String userId;

  Future<Database> get _db => LocalDatabase.instance.db;

  /// Añade (o reemplaza) una operación en la cola.
  ///
  /// El esquema de IDs (`<entityId>_<opType>`) garantiza que sólo
  /// existe un `create`, un `update` y un `delete` por entidad:
  /// - Dos `update` seguidos → el segundo reemplaza al primero (correcto).
  /// - Un `create` seguido de `delete` → ambos coexisten y se procesan en orden.
  Future<void> enqueue(PendingOperation op) async {
    final db = await _db;
    await db.insert(
      'pending_operations',
      op.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Devuelve todas las operaciones pendientes del usuario ordenadas por fecha
  /// de creación (FIFO).
  Future<List<PendingOperation>> getPending() async {
    final db = await _db;
    final rows = await db.query(
      'pending_operations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingOperation.fromRow).toList();
  }

  /// Elimina una operación completada con éxito.
  Future<void> remove(String id) async {
    final db = await _db;
    await db.delete(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Incrementa el contador de intentos fallidos.
  Future<void> incrementAttempts(String id) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE pending_operations SET attempts = attempts + 1 WHERE id = ?',
      [id],
    );
  }

  /// Elimina toda la cola del usuario (p.ej. al cambiar de plan).
  Future<void> clearAll() async {
    final db = await _db;
    await db.delete(
      'pending_operations',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

/// Cola de sync ligada al usuario autenticado actual.
/// Lanza [StateError] si se lee sin sesión (ver nota en
/// [localTransactionsRepositoryProvider]).
final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('syncQueueRepositoryProvider leído sin usuario autenticado');
  }
  return SyncQueueRepository(userId: user.id);
});
