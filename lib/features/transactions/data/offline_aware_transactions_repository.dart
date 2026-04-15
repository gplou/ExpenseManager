import 'package:flutter/foundation.dart';

import '../../../core/utils/date_helpers.dart';
import '../domain/cloud_transaction_sync_contract.dart';
import '../domain/transaction_model.dart';
import '../domain/transactions_repository_contract.dart';
import 'local_transactions_repository.dart';
import 'pending_operation.dart';
import 'sync_queue_repository.dart';

/// Repository para usuarios PRO con soporte offline-first.
///
/// Flujo de escritura:
///   1. Guarda siempre en SQLite local (respuesta instantánea al usuario).
///   2. Intenta subir a Supabase. Si falla (sin red, error transitorio…)
///      encola la operación para que [OfflineSyncService] la reintente.
///
/// Se intenta siempre la llamada a la nube; el try/catch gestiona el offline.
/// Esto evita bloqueos por falsos negativos de connectivity_plus en Android.
///
/// Depende de [CloudTransactionSyncContract] en lugar de [TransactionsRepository]
/// directamente, cumpliendo el principio DIP de SOLID.
class OfflineAwareTransactionsRepository
    implements TransactionsRepositoryContract {
  const OfflineAwareTransactionsRepository({
    required CloudTransactionSyncContract cloud,
    required LocalTransactionsRepository local,
    required SyncQueueRepository queue,
    // isOnline conservado en constructor para no romper el provider existente.
    bool isOnline = true,
  })  : _cloud = cloud,
        _local = local,
        _queue = queue;

  final CloudTransactionSyncContract _cloud;
  final LocalTransactionsRepository _local;
  final SyncQueueRepository _queue;

  // ── Lecturas ─────────────────────────────────────────────────────────────

  @override
  Future<List<TransactionModel>> getTransactions({
    required DateTime from,
    required DateTime to,
  }) =>
      _local.getTransactions(from: from, to: to);

  @override
  Future<TransactionsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) =>
      _local.getSummary(from: from, to: to);

  // ── Escrituras ────────────────────────────────────────────────────────────

  @override
  Future<TransactionModel> createTransaction(TransactionModel transaction) async {
    final saved = await _local.createTransaction(transaction);
    try {
      await _cloud.upsertTransaction(saved);
    } catch (e) {
      debugPrint('OfflineAware.createTransaction: cloud upsert failed, enqueuing — $e');
      await _enqueue(SyncOpType.create, saved);
    }
    return saved;
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) async {
    final saved = await _local.updateTransaction(transaction);
    try {
      await _cloud.upsertTransaction(saved);
    } catch (e) {
      debugPrint('OfflineAware.updateTransaction: cloud upsert failed, enqueuing — $e');
      await _enqueue(SyncOpType.update, saved);
    }
    return saved;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _local.deleteTransaction(id);
    try {
      await _cloud.deleteTransaction(id);
    } catch (e) {
      debugPrint('OfflineAware.deleteTransaction: cloud delete failed, enqueuing — $e');
      await _enqueueDelete(id);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _enqueue(SyncOpType opType, TransactionModel t) async {
    await _queue.enqueue(PendingOperation(
      id: '${t.id}_${opType.name}',
      userId: t.userId,
      opType: opType,
      entityId: t.id,
      payload: {
        'id': t.id,
        'user_id': t.userId,
        'amount': t.amount,
        'type': t.type.name,
        'category': t.category,
        'subcategory': t.subcategory,
        'description': t.description,
        'date': dateToString(t.date),
        'currency': t.currency,
        'recurring_transaction_id': t.recurringTransactionId,
        'created_at': t.createdAt.toIso8601String(),
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _enqueueDelete(String entityId) async {
    await _queue.enqueue(PendingOperation(
      id: '${entityId}_delete',
      userId: _local.userId,
      opType: SyncOpType.delete,
      entityId: entityId,
      createdAt: DateTime.now(),
    ));
  }
}
