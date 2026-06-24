import 'dart:convert';

enum SyncOpType {
  create,
  update,
  delete,

  /// Tombstone for a recurring transaction deleted while FREE. Stored in the
  /// same `pending_operations` table but consumed ONLY by the FREE→PRO migration
  /// ([TransactionSyncService.migrateToCloud]) — [OfflineSyncService] skips it,
  /// since recurring transactions have no offline-sync queue (PRO writes them
  /// straight to Supabase). The `entity_id` is the recurring transaction id.
  deleteRecurring,
}

/// Representa una operación de escritura pendiente de sincronizar con Supabase.
///
/// El [id] sigue el patrón `<entityId>_<opType>` lo que garantiza que:
/// - Sólo existe un pendiente de cada tipo por entidad.
/// - Un segundo `update` reemplaza el primero (ConflictAlgorithm.replace).
class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.userId,
    required this.opType,
    required this.entityId,
    this.payload,
    required this.createdAt,
    this.attempts = 0,
  });

  final String id;
  final String userId;
  final SyncOpType opType;
  final String entityId;

  /// JSON completo de la transacción (nulo para deletes).
  final Map<String, dynamic>? payload;
  final DateTime createdAt;
  final int attempts;

  factory PendingOperation.fromRow(Map<String, dynamic> row) =>
      PendingOperation(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        opType: SyncOpType.values.byName(row['op_type'] as String),
        entityId: row['entity_id'] as String,
        payload: row['payload'] != null
            ? jsonDecode(row['payload'] as String) as Map<String, dynamic>
            : null,
        createdAt: DateTime.parse(row['created_at'] as String),
        attempts: (row['attempts'] as int?) ?? 0,
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'user_id': userId,
        'op_type': opType.name,
        'entity_id': entityId,
        'payload': payload != null ? jsonEncode(payload) : null,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
      };
}
