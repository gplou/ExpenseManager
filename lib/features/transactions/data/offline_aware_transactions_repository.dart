import 'package:clock/clock.dart';

import 'package:expense_manager/core/utils/date_helpers.dart';
import 'package:expense_manager/core/utils/transaction_id_generator.dart';
import 'package:expense_manager/features/transactions/domain/cloud_transaction_sync_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transactions_repository_contract.dart';
import 'package:expense_manager/core/utils/app_logger.dart';
import 'local_transactions_repository.dart';
import 'pending_operation.dart';
import 'sync_queue_repository.dart';

/// Repository para usuarios PRO con soporte offline-first.
///
/// Flujo de escritura:
///   1. Intenta guardar en SQLite local (respuesta instantánea al usuario).
///   2. Intenta subir a Supabase. Si falla (sin red, error transitorio…)
///      encola la operación para que [OfflineSyncService] la reintente.
///
/// Si la escritura local falla (DB corrupta, Keystore hang en Android…)
/// se sigue intentando la subida a Supabase con el id ya estampado para no
/// dejar al usuario sin poder guardar. El read-path ya tiene su propio
/// fallback a cloud cuando SQLite no está disponible, así que el siguiente
/// rebuild del listado mostrará la transacción aunque local no funcione.
///
/// Depende de [CloudTransactionSyncContract] en lugar de [TransactionsRepository]
/// directamente, cumpliendo el principio DIP de SOLID.
class OfflineAwareTransactionsRepository
    implements TransactionsRepositoryContract {
  const OfflineAwareTransactionsRepository({
    required CloudTransactionSyncContract cloud,
    required LocalTransactionsRepository local,
    required SyncQueueRepository queue,
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
    // Estampar id/userId antes del local para que el path cloud-only conserve
    // el mismo id si SQLite falla. El guard `id.isNotEmpty` de
    // LocalTransactionsRepository preserva este id en el happy path.
    final stamped = transaction.copyWith(
      id: transaction.id.isNotEmpty
          ? transaction.id
          : TransactionIdGenerator.generate(_local.userId),
      userId: _local.userId,
    );

    TransactionModel saved = stamped;
    bool localOk = false;
    try {
      saved = await _local.createTransaction(stamped);
      localOk = true;
    } catch (e, st) {
      AppLogger.log(
        'OfflineAware.createTransaction: local failed, trying cloud only — $e\n$st',
      );
    }

    try {
      await _cloud.upsertTransaction(saved);
      return saved;
    } catch (e) {
      AppLogger.log('OfflineAware.createTransaction: cloud upsert failed — $e');
      if (localOk) {
        await _enqueue(SyncOpType.create, saved);
        return saved;
      }
      rethrow; // local y cloud fallaron — el usuario verá errorSaving
    }
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) async {
    TransactionModel saved = transaction;
    bool localOk = false;
    try {
      saved = await _local.updateTransaction(transaction);
      localOk = true;
    } catch (e, st) {
      AppLogger.log(
        'OfflineAware.updateTransaction: local failed, trying cloud only — $e\n$st',
      );
    }

    try {
      await _cloud.upsertTransaction(saved);
      return saved;
    } catch (e) {
      AppLogger.log('OfflineAware.updateTransaction: cloud upsert failed — $e');
      if (localOk) {
        await _enqueue(SyncOpType.update, saved);
        return saved;
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    bool localOk = false;
    try {
      await _local.deleteTransaction(id);
      localOk = true;
    } catch (e, st) {
      AppLogger.log(
        'OfflineAware.deleteTransaction: local failed, trying cloud only — $e\n$st',
      );
    }

    try {
      await _cloud.deleteTransaction(id);
    } catch (e) {
      AppLogger.log('OfflineAware.deleteTransaction: cloud delete failed — $e');
      if (localOk) {
        await _enqueueDelete(id);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> upsertTransaction(TransactionModel transaction) async {
    bool localOk = false;
    try {
      await _local.upsertTransaction(transaction);
      localOk = true;
    } catch (e, st) {
      AppLogger.log(
        'OfflineAware.upsertTransaction: local failed, trying cloud only — $e\n$st',
      );
    }

    try {
      await _cloud.upsertTransaction(transaction);
    } catch (e) {
      AppLogger.log('OfflineAware.upsertTransaction: cloud upsert failed — $e');
      if (localOk) {
        await _enqueue(SyncOpType.update, transaction);
        return;
      }
      rethrow;
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
      createdAt: clock.now(),
    ));
  }

  Future<void> _enqueueDelete(String entityId) async {
    await _queue.enqueue(PendingOperation(
      id: '${entityId}_delete',
      userId: _local.userId,
      opType: SyncOpType.delete,
      entityId: entityId,
      createdAt: clock.now(),
    ));
  }
}
