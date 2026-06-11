import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expense_manager/core/errors/failures.dart';
import 'package:expense_manager/core/network/connectivity_service.dart';
import 'package:expense_manager/core/network/supabase_client.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/domain/cloud_transaction_sync_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/core/utils/app_logger.dart';
import 'pending_operation.dart';
import 'sync_queue_repository.dart';
import 'transactions_repository.dart';

/// Provider de la abstracción de sync en la nube.
/// Permite sustituirlo en tests sin tocar el Supabase real.
final cloudTransactionSyncProvider = Provider<CloudTransactionSyncContract>((ref) {
  return TransactionsRepository(ref.watch(supabaseClientProvider));
});

/// Provider que arranca el [OfflineSyncService] una vez y lo mantiene vivo.
/// Basta con watchearlo en el widget raíz de la app.
final offlineSyncServiceProvider = Provider<void>((ref) {
  OfflineSyncService(ref).start();
});

/// Escucha los cambios de conectividad y, cuando se recupera la conexión,
/// sube a Supabase todas las operaciones pendientes de la cola.
///
/// Solo actúa para usuarios PRO autenticados.
/// Las operaciones se procesan en orden FIFO y se eliminan de la cola
/// únicamente cuando Supabase confirma el éxito.
class OfflineSyncService {
  OfflineSyncService(this._ref);

  final Ref _ref;
  bool _flushing = false;

  /// Inicia los listeners. Llamar una vez desde el widget raíz de la app.
  void start() {
    // Flush cuando la suscripción se confirma como PRO.
    // El microtask inicial llega demasiado pronto (subscriptionProvider aún
    // carga) y el flush aborta con isPro=false. Este listener cubre tanto
    // el primer arranque como los cambios de plan durante la sesión.
    _ref.listen<bool>(isProProvider, (prev, next) {
      if (prev != true && next == true) _flush();
    });

    // Flush al recuperar conexión — procesa items encolados por estar offline.
    _ref.listen(connectivityProvider, (prev, next) {
      if (next.value == true) _flush();
    });
  }

  Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _doFlush();
    } finally {
      _flushing = false;
    }
  }

  // Ops que superen este límite se descartan para evitar queue poisoning.
  static const _maxAttempts = 5;

  Future<void> _doFlush() async {
    final user = _ref.read(currentUserProvider);
    final isPro = _ref.read(isProProvider);
    if (user == null || !isPro) return;

    final queue = _ref.read(syncQueueRepositoryProvider);
    final pending = await queue.getPending();
    if (pending.isEmpty) return;

    final cloud = _ref.read(cloudTransactionSyncProvider);
    bool anySuccess = false;

    for (final op in pending) {
      // Descartar ops que han fallado demasiadas veces para evitar queue poisoning.
      if (op.attempts >= _maxAttempts) {
        AppLogger.log(
          'OfflineSyncService: dropping op ${op.id} after $_maxAttempts failed attempts',
        );
        await queue.remove(op.id);
        continue;
      }

      try {
        await _apply(cloud, op);
        await queue.remove(op.id);
        anySuccess = true;
      } on AuthException {
        // Token expirado o sesión revocada — no tiene sentido continuar con
        // el resto de ops porque todas fallarán con el mismo error.
        AppLogger.log('OfflineSyncService: auth error, aborting flush');
        break;
      } on AuthFailure {
        AppLogger.log('OfflineSyncService: auth failure, aborting flush');
        break;
      } catch (e) {
        await queue.incrementAttempts(op.id);
        AppLogger.log(
          'OfflineSyncService: failed op ${op.id} '
          '(${op.attempts + 1}/$_maxAttempts attempts): $e',
        );
      }
    }

    // Refresca la UI sólo si al menos una op se sincronizó.
    if (anySuccess) {
      _ref.invalidate(allTransactionsProvider);
    }
  }

  Future<void> _apply(CloudTransactionSyncContract cloud, PendingOperation op) async {
    switch (op.opType) {
      case SyncOpType.create:
      case SyncOpType.update:
        await cloud.upsertTransaction(_transactionFromPayload(op.payload!));
      case SyncOpType.delete:
        await cloud.deleteTransaction(op.entityId);
    }
  }

  /// Reconstruye un [TransactionModel] desde el mapa JSON plano del payload.
  static TransactionModel _transactionFromPayload(Map<String, dynamic> p) =>
      TransactionModel(
        id: p['id'] as String,
        userId: p['user_id'] as String,
        amount: (p['amount'] as num).toDouble(),
        type: TransactionType.values.byName(p['type'] as String),
        category: p['category'] as String,
        subcategory: p['subcategory'] as String?,
        description: p['description'] as String?,
        date: DateTime.parse(p['date'] as String),
        createdAt: DateTime.parse(p['created_at'] as String),
        currency: p['currency'] as String? ?? 'EUR',
        recurringTransactionId: p['recurring_transaction_id'] as String?,
      );
}
