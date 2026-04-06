/// Integration tests for [OfflineSyncService].
///
/// Strategy:
///   - Real SQLite in-memory DB for the queue.
///   - Override [cloudTransactionSyncProvider] with a fake to capture cloud calls.
///   - Override [connectivityProvider] with a controllable stream.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_manager/core/local_db/local_database.dart';
import 'package:expense_manager/core/network/connectivity_service.dart';
import 'package:expense_manager/features/auth/domain/user_model.dart';
import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/subscription/subscription_provider.dart';
import 'package:expense_manager/features/transactions/data/offline_sync_service.dart';
import 'package:expense_manager/features/transactions/data/pending_operation.dart';
import 'package:expense_manager/features/transactions/data/sync_queue_repository.dart';
import 'package:expense_manager/features/transactions/domain/cloud_transaction_sync_contract.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class FakeCloudSync implements CloudTransactionSyncContract {
  final List<String> upsertedIds = [];
  final List<String> deletedIds = [];
  bool failNext = false;

  @override
  Future<void> upsertTransaction(TransactionModel t) async {
    if (failNext) {
      failNext = false;
      throw Exception('network error');
    }
    upsertedIds.add(t.id);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    if (failNext) {
      failNext = false;
      throw Exception('network error');
    }
    deletedIds.add(id);
  }
}

class _SelectiveFakeCloudSync implements CloudTransactionSyncContract {
  _SelectiveFakeCloudSync({required this.failOnCallNumber});

  final int failOnCallNumber;
  int _callCount = 0;
  final List<String> upsertedIds = [];
  final List<String> deletedIds = [];

  @override
  Future<void> upsertTransaction(TransactionModel t) async {
    _callCount++;
    if (_callCount == failOnCallNumber) throw Exception('selective failure');
    upsertedIds.add(t.id);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _callCount++;
    if (_callCount == failOnCallNumber) throw Exception('selective failure');
    deletedIds.add(id);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _userId = 'user-pro';

final _fakeUser = UserModel(
  id: _userId,
  email: 'pro@test.com',
  createdAt: DateTime(2024, 1, 1),
);

/// Provider auxiliar que captura el [Ref] real para iniciar el servicio.
final _startSyncProvider = Provider<void>((ref) {
  OfflineSyncService(ref).start();
});

PendingOperation makeCreateOp(String txId, {DateTime? createdAt}) =>
    PendingOperation(
      id: '${txId}_create',
      userId: _userId,
      opType: SyncOpType.create,
      entityId: txId,
      payload: {
        'id': txId,
        'user_id': _userId,
        'amount': 50.0,
        'type': 'expense',
        'category': 'Comida',
        'date': '2024-06-01',
        'currency': 'EUR',
        'created_at': '2024-06-01T00:00:00.000',
      },
      createdAt: createdAt ?? DateTime(2024, 6, 1),
    );

PendingOperation makeDeleteOp(String txId) => PendingOperation(
      id: '${txId}_delete',
      userId: _userId,
      opType: SyncOpType.delete,
      entityId: txId,
      createdAt: DateTime(2024, 6, 2),
    );

ProviderContainer makeContainer({
  required CloudTransactionSyncContract fakeCloud,
  required Stream<bool> connectivityStream,
  bool isPro = true,
  bool loggedOut = false,
}) =>
    ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => loggedOut ? null : _fakeUser),
        isProProvider.overrideWith((ref) => isPro),
        connectivityProvider.overrideWith((ref) => connectivityStream),
        isOnlineProvider.overrideWith((ref) => true),
        cloudTransactionSyncProvider.overrideWith((ref) => fakeCloud),
      ],
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();

  late SyncQueueRepository queue;
  late FakeCloudSync fakeCloud;
  late StreamController<bool> connectivityCtrl;

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(':memory:');
    await LocalDatabase.createSchema(db);
    LocalDatabase.instance.setTestDb(db);

    queue = SyncQueueRepository(userId: _userId);
    fakeCloud = FakeCloudSync();
    connectivityCtrl = StreamController<bool>.broadcast();
  });

  tearDown(() async {
    await connectivityCtrl.close();
    await LocalDatabase.instance.close();
  });

  Future<void> triggerReconnect(ProviderContainer container) async {
    container.read(_startSyncProvider); // attaches listener
    connectivityCtrl.add(false);
    connectivityCtrl.add(true);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // ── Tests ──────────────────────────────────────────────────────────────────

  test('does nothing when queue is empty on reconnect', () async {
    final container = makeContainer(
      fakeCloud: fakeCloud,
      connectivityStream: connectivityCtrl.stream,
    );
    addTearDown(container.dispose);

    await triggerReconnect(container);

    expect(fakeCloud.upsertedIds, isEmpty);
    expect(fakeCloud.deletedIds, isEmpty);
  });

  test('flushes create ops to cloud on reconnect', () async {
    await queue.enqueue(makeCreateOp('tx-1'));
    await queue.enqueue(makeCreateOp('tx-2'));

    final container = makeContainer(
      fakeCloud: fakeCloud,
      connectivityStream: connectivityCtrl.stream,
    );
    addTearDown(container.dispose);

    await triggerReconnect(container);

    expect(fakeCloud.upsertedIds, containsAll(['tx-1', 'tx-2']));
  });

  test('removes ops from queue after successful sync', () async {
    await queue.enqueue(makeCreateOp('tx-3'));

    final container = makeContainer(
      fakeCloud: fakeCloud,
      connectivityStream: connectivityCtrl.stream,
    );
    addTearDown(container.dispose);

    await triggerReconnect(container);

    expect(await queue.getPending(), isEmpty);
  });

  test('flushes delete ops to cloud on reconnect', () async {
    await queue.enqueue(makeDeleteOp('tx-del'));

    final container = makeContainer(
      fakeCloud: fakeCloud,
      connectivityStream: connectivityCtrl.stream,
    );
    addTearDown(container.dispose);

    await triggerReconnect(container);

    expect(fakeCloud.deletedIds, contains('tx-del'));
  });

  test('increments attempt count and keeps op when cloud call fails', () async {
    await queue.enqueue(makeCreateOp('tx-fail'));
    fakeCloud.failNext = true;

    final container = makeContainer(
      fakeCloud: fakeCloud,
      connectivityStream: connectivityCtrl.stream,
    );
    addTearDown(container.dispose);

    await triggerReconnect(container);

    final pending = await queue.getPending();
    expect(pending.length, 1);
    expect(pending.first.attempts, 1);
    expect(fakeCloud.upsertedIds, isEmpty);
  });

  test('processes ops in FIFO order', () async {
    await queue.enqueue(makeCreateOp('tx-first',  createdAt: DateTime(2024, 6, 1)));
    await queue.enqueue(makeCreateOp('tx-second', createdAt: DateTime(2024, 6, 2)));

    final container = makeContainer(
      fakeCloud: fakeCloud,
      connectivityStream: connectivityCtrl.stream,
    );
    addTearDown(container.dispose);

    await triggerReconnect(container);

    expect(
      fakeCloud.upsertedIds.indexOf('tx-first'),
      lessThan(fakeCloud.upsertedIds.indexOf('tx-second')),
    );
  });

  test('does not flush if user is not PRO', () async {
    await queue.enqueue(makeCreateOp('tx-free'));

    final container = makeContainer(
      fakeCloud: fakeCloud,
      connectivityStream: connectivityCtrl.stream,
      isPro: false,
    );
    addTearDown(container.dispose);

    await triggerReconnect(container);

    expect(fakeCloud.upsertedIds, isEmpty);
  });

  test('does not flush if user is logged out', () async {
    await queue.enqueue(makeCreateOp('tx-logout'));

    final container = makeContainer(
      fakeCloud: fakeCloud,
      connectivityStream: connectivityCtrl.stream,
      loggedOut: true,
    );
    addTearDown(container.dispose);

    await triggerReconnect(container);

    expect(fakeCloud.upsertedIds, isEmpty);
  });

  test('partial flush: successful ops removed, failed ops kept', () async {
    final selectiveFake = _SelectiveFakeCloudSync(failOnCallNumber: 2);

    await queue.enqueue(makeCreateOp('tx-ok',   createdAt: DateTime(2024, 6, 1)));
    await queue.enqueue(makeCreateOp('tx-fail', createdAt: DateTime(2024, 6, 2)));

    final container = makeContainer(
      fakeCloud: selectiveFake,
      connectivityStream: connectivityCtrl.stream,
    );
    addTearDown(container.dispose);

    await triggerReconnect(container);

    final pending = await queue.getPending();
    expect(pending.length, 1);
    expect(pending.first.entityId, 'tx-fail');
    expect(selectiveFake.upsertedIds, contains('tx-ok'));
  });
}
