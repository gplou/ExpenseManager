import '../../../core/utils/date_helpers.dart';
import '../domain/cloud_transaction_sync_contract.dart';
import '../domain/transaction_model.dart';
import '../domain/transactions_repository_contract.dart';
import 'local_transactions_repository.dart';
import 'pending_operation.dart';
import 'sync_queue_repository.dart';

/// Repository para usuarios PRO con soporte offline-first.
///
/// - Lecturas: siempre desde SQLite (caché local, < 100ms).
/// - Escrituras con conexión: Supabase primero, luego actualiza caché local.
/// - Escrituras sin conexión: SQLite primero, encola la op para sincronizar
///   cuando se recupere la conexión.
///
/// Depende de [CloudTransactionSyncContract] (abstracción) en lugar de la clase
/// concreta [TransactionsRepository], cumpliendo el principio DIP de SOLID.
class OfflineAwareTransactionsRepository
    implements TransactionsRepositoryContract {
  const OfflineAwareTransactionsRepository({
    required CloudTransactionSyncContract cloud,
    required LocalTransactionsRepository local,
    required SyncQueueRepository queue,
    required bool isOnline,
  })  : _cloud = cloud,
        _local = local,
        _queue = queue,
        _isOnline = isOnline;

  final CloudTransactionSyncContract _cloud;
  final LocalTransactionsRepository _local;
  final SyncQueueRepository _queue;
  final bool _isOnline;

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
    // Guarda primero en local (siempre disponible y da feedback instantáneo).
    final saved = await _local.createTransaction(transaction);

    if (_isOnline) {
      // Sube a la nube. Si falla, encola para reintentar más tarde.
      try {
        await _cloud.upsertTransaction(saved);
      } catch (_) {
        await _enqueue(SyncOpType.create, saved);
      }
    } else {
      await _enqueue(SyncOpType.create, saved);
    }

    return saved;
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) async {
    final saved = await _local.updateTransaction(transaction);

    if (_isOnline) {
      try {
        await _cloud.upsertTransaction(saved);
      } catch (_) {
        await _enqueue(SyncOpType.update, saved);
      }
    } else {
      await _enqueue(SyncOpType.update, saved);
    }

    return saved;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _local.deleteTransaction(id);

    if (_isOnline) {
      try {
        await _cloud.deleteTransaction(id);
      } catch (_) {
        await _enqueueDelete(id);
      }
    } else {
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
