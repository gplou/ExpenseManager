import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/pending_operation.dart';

void main() {
  final now = DateTime(2024, 6, 1, 12, 0, 0);

  PendingOperation makePendingOp({
    String id = 'tx-1_create',
    String userId = 'user-1',
    SyncOpType opType = SyncOpType.create,
    String entityId = 'tx-1',
    Map<String, dynamic>? payload,
    int attempts = 0,
  }) =>
      PendingOperation(
        id: id,
        userId: userId,
        opType: opType,
        entityId: entityId,
        payload: payload ?? {'amount': 50.0, 'type': 'expense'},
        createdAt: now,
        attempts: attempts,
      );

  group('PendingOperation.toRow / fromRow', () {
    test('round-trips a create operation', () {
      final op = makePendingOp();
      final row = op.toRow();
      final restored = PendingOperation.fromRow(row);

      expect(restored.id, op.id);
      expect(restored.userId, op.userId);
      expect(restored.opType, SyncOpType.create);
      expect(restored.entityId, op.entityId);
      expect(restored.payload, op.payload);
      expect(restored.createdAt, op.createdAt);
      expect(restored.attempts, 0);
    });

    test('round-trips an update operation', () {
      final op = makePendingOp(id: 'tx-2_update', opType: SyncOpType.update);
      final restored = PendingOperation.fromRow(op.toRow());
      expect(restored.opType, SyncOpType.update);
    });

    test('round-trips a delete operation with null payload', () {
      final op = PendingOperation(
        id: 'tx-3_delete',
        userId: 'user-1',
        opType: SyncOpType.delete,
        entityId: 'tx-3',
        createdAt: now,
      );
      final row = op.toRow();
      expect(row['payload'], isNull);

      final restored = PendingOperation.fromRow(row);
      expect(restored.payload, isNull);
      expect(restored.opType, SyncOpType.delete);
    });

    test('payload is stored as JSON string in the row', () {
      final op = makePendingOp(payload: {'amount': 99.5, 'currency': 'USD'});
      final row = op.toRow();
      expect(row['payload'], isA<String>());
      final decoded = jsonDecode(row['payload'] as String);
      expect(decoded['amount'], 99.5);
      expect(decoded['currency'], 'USD');
    });

    test('preserves attempt count through serialisation', () {
      final op = makePendingOp(attempts: 3);
      final restored = PendingOperation.fromRow(op.toRow());
      expect(restored.attempts, 3);
    });
  });

  group('ID scheme', () {
    test('create ID follows <entityId>_create pattern', () {
      final op = makePendingOp(id: 'tx-abc_create', entityId: 'tx-abc');
      expect(op.id, 'tx-abc_create');
    });

    test('delete ID follows <entityId>_delete pattern', () {
      final op = makePendingOp(id: 'tx-abc_delete', opType: SyncOpType.delete);
      expect(op.id, 'tx-abc_delete');
    });
  });
}
