import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/data/backup_service.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

TransactionModel _tx({
  String id = 't1',
  double amount = 25.5,
  TransactionType type = TransactionType.expense,
  String category = 'Comida',
  String? subcategory,
  String? description,
  DateTime? date,
  String currency = 'EUR',
}) =>
    TransactionModel(
      id: id,
      userId: 'u1',
      amount: amount,
      type: type,
      category: category,
      subcategory: subcategory,
      description: description,
      date: date ?? DateTime(2026, 3, 15),
      createdAt: DateTime(2026, 3, 15, 12),
      currency: currency,
    );

RecurringTransactionModel _recurring({String id = 'r1'}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'u1',
      amount: 9.99,
      type: TransactionType.expense,
      category: 'Ocio',
      description: 'Netflix',
      recurrenceType: RecurrenceType.monthly,
      nextOccurrence: DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('JSON export/import roundtrip', () {
    test('buildBackupJson includes marker, version and both collections', () {
      final json = withClock(
        Clock.fixed(DateTime(2026, 6, 12)),
        () => BackupService.buildBackupJson([_tx()], [_recurring()]),
      );

      expect(json['app'], 'ExpenseManager');
      expect(json['version'], BackupService.backupFormatVersion);
      expect(json['exported_at'], DateTime(2026, 6, 12).toIso8601String());
      expect(json['transactions'], hasLength(1));
      expect(json['recurring_transactions'], hasLength(1));
      expect(
        (json['recurring_transactions'] as List).single['recurrenceType'],
        'monthly',
      );
    });

    test('parse(json) recovers the transactions with sanitized ids', () {
      final original = _tx(
        description: 'Cena con Ana',
        subcategory: 'Restaurante',
        currency: 'USD',
      );
      final content = withClock(
        Clock.fixed(DateTime(2026, 6, 12)),
        () => BackupService.buildBackupJson([original], const []),
      );

      final result = BackupService.parse(jsonEncode(content));

      expect(result.invalidCount, 0);
      final t = result.valid.single;
      expect(t.id, isEmpty); // re-import seguro: el repo genera id nuevo
      expect(t.userId, isEmpty);
      expect(t.amount, original.amount);
      expect(t.category, original.category);
      expect(t.subcategory, original.subcategory);
      expect(t.description, original.description);
      expect(t.currency, 'USD');
      expect(t.date, original.date);
    });

    test('counts corrupt items as invalid without dropping the rest', () {
      const content = '''
      {"app":"ExpenseManager","version":1,"transactions":[
        {"id":"a","userId":"u","amount":10,"type":"expense","category":"Comida",
         "date":"2026-03-15T00:00:00.000","createdAt":"2026-03-15T00:00:00.000"},
        {"esto":"no es una transacción"}
      ]}''';
      final result = BackupService.parse(content);
      expect(result.valid, hasLength(1));
      expect(result.invalidCount, 1);
    });

    test('rejects JSON from another app', () {
      expect(
        () => BackupService.parse('{"app":"OtraApp","transactions":[]}'),
        throwsFormatException,
      );
      expect(() => BackupService.parse('{no json}'), throwsFormatException);
    });
  });

  group('CSV export/import roundtrip', () {
    test('buildCsv emits the documented header and ISO/dot formats', () {
      final csv = BackupService.buildCsv([
        _tx(description: 'Taxi, aeropuerto', amount: 12.5),
      ]);
      final lines = csv.split('\n');
      expect(lines.first.trim(), BackupService.csvHeader.join(','));
      // La descripción con coma va entrecomillada; fecha ISO; decimal con punto.
      expect(lines[1], contains('2026-03-15'));
      expect(lines[1], contains('12.50'));
      expect(lines[1], contains('"Taxi, aeropuerto"'));
    });

    test('parse(csv) recovers the rows', () {
      final csv = BackupService.buildCsv([
        _tx(description: 'Cena', subcategory: 'Restaurante'),
        _tx(id: 't2', type: TransactionType.income, category: 'Salario',
            amount: 1500),
      ]);
      final result = withClock(
        Clock.fixed(DateTime(2026, 6, 12)),
        () => BackupService.parse(csv),
      );

      expect(result.invalidCount, 0);
      expect(result.valid, hasLength(2));
      expect(result.valid[0].description, 'Cena');
      expect(result.valid[0].subcategory, 'Restaurante');
      expect(result.valid[1].type, TransactionType.income);
      expect(result.valid[1].amount, 1500);
    });

    test('counts unparseable rows as invalid', () {
      final csv = [
        BackupService.csvHeader.join(','),
        '2026-03-15,expense,Comida,,,10.00,EUR',
        'no-es-fecha,expense,Comida,,,10.00,EUR',
        '2026-03-15,expense,Comida,,,-5.00,EUR',
        '2026-03-15,viaje,Comida,,,10.00,EUR',
      ].join('\n');
      final result = withClock(
        Clock.fixed(DateTime(2026, 6, 12)),
        () => BackupService.parse(csv),
      );
      expect(result.valid, hasLength(1));
      expect(result.invalidCount, 3);
    });

    test('rejects a CSV with a foreign header', () {
      expect(
        () => BackupService.parse('fecha;importe\n2026-01-01;10'),
        throwsFormatException,
      );
    });
  });

  group('dedup', () {
    test('drops incoming transactions already present', () {
      final existing = [_tx(description: 'Cena')];
      final incoming = [
        _tx(id: '', description: 'Cena'), // misma fecha/importe/cat/desc
        _tx(id: '', description: 'Otra cosa'),
      ];
      final result = BackupService.dedup(incoming, existing);
      expect(result, hasLength(1));
      expect(result.single.description, 'Otra cosa');
    });

    test('also deduplicates within the imported file itself', () {
      final incoming = [
        _tx(id: '', description: 'Cena'),
        _tx(id: '', description: 'Cena'),
      ];
      expect(BackupService.dedup(incoming, const []), hasLength(1));
    });

    test('different amount or date is not a duplicate', () {
      final existing = [_tx()];
      final incoming = [
        _tx(id: '', amount: 99),
        _tx(id: '', date: DateTime(2026, 3, 16)),
      ];
      expect(BackupService.dedup(incoming, existing), hasLength(2));
    });
  });
}
