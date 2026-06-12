import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';

/// Resultado de parsear un archivo de backup: transacciones válidas
/// (con id/userId vacíos — los estampa el repositorio al insertar) y el
/// número de filas/objetos que no se pudieron interpretar.
class BackupParseResult {
  const BackupParseResult({required this.valid, required this.invalidCount});

  final List<TransactionModel> valid;
  final int invalidCount;
}

/// Export/import de copias de seguridad (Plan 3 — A4).
///
/// v1 solo acepta el FORMATO PROPIO (JSON completo o el CSV que exporta esta
/// misma clase) — evita el infierno de formatos de fecha/decimales de CSVs
/// arbitrarios. El import es solo de transacciones; las recurrentes viajan en
/// el JSON como respaldo de datos pero no se re-importan en v1.
class BackupService {
  BackupService._();

  static const backupFormatVersion = 1;
  static const _appMarker = 'ExpenseManager';

  /// Cabecera del CSV propio. El import valida contra esta cabecera.
  static const csvHeader = [
    'date',
    'type',
    'category',
    'subcategory',
    'description',
    'amount',
    'currency',
  ];

  // ── Export (builders puros) ────────────────────────────────────────────────

  static Map<String, dynamic> buildBackupJson(
    List<TransactionModel> transactions,
    List<RecurringTransactionModel> recurring,
  ) =>
      {
        'app': _appMarker,
        'version': backupFormatVersion,
        'exported_at': clock.now().toIso8601String(),
        'transactions': [for (final t in transactions) t.toJson()],
        'recurring_transactions': [
          for (final r in recurring)
            {
              'id': r.id,
              'userId': r.userId,
              'amount': r.amount,
              'type': r.type.name,
              'category': r.category,
              'subcategory': r.subcategory,
              'description': r.description,
              'recurrenceType': r.recurrenceType.name,
              'nextOccurrence': r.nextOccurrence.toIso8601String(),
              'createdAt': r.createdAt.toIso8601String(),
            },
        ],
      };

  /// CSV simple: fechas ISO (yyyy-MM-dd), decimales con punto y claves de
  /// categoría en crudo (es), para que el round-trip export→import sea exacto.
  static String buildCsv(List<TransactionModel> transactions) {
    final rows = <List<dynamic>>[
      csvHeader,
      for (final t in transactions)
        [
          DateFormat('yyyy-MM-dd').format(t.date),
          t.type.name,
          t.category,
          t.subcategory ?? '',
          t.description ?? '',
          t.amount.toStringAsFixed(2),
          t.currency,
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  // ── Export (archivo + share sheet) ─────────────────────────────────────────

  static Future<void> exportJson(
    List<TransactionModel> transactions,
    List<RecurringTransactionModel> recurring,
  ) async {
    final content = const JsonEncoder.withIndent('  ')
        .convert(buildBackupJson(transactions, recurring));
    await _shareFile(content, extension: 'json', mimeType: 'application/json');
  }

  static Future<void> exportCsv(List<TransactionModel> transactions) async {
    await _shareFile(buildCsv(transactions),
        extension: 'csv', mimeType: 'text/csv');
  }

  static Future<void> _shareFile(
    String content, {
    required String extension,
    required String mimeType,
  }) async {
    final fileName =
        'ExpenseManager_${DateFormat('yyyyMMdd').format(clock.now())}.$extension';
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: mimeType)],
        subject: fileName,
      ),
    );
  }

  // ── Import (parser puro) ───────────────────────────────────────────────────

  /// Detecta el formato por contenido (JSON propio u CSV propio) y devuelve
  /// las transacciones interpretables. Lanza [FormatException] si el archivo
  /// no es ninguno de los dos formatos propios.
  static BackupParseResult parse(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{')) return _parseJson(trimmed);
    return _parseCsv(trimmed);
  }

  static BackupParseResult _parseJson(String content) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      throw const FormatException('Not a valid backup file');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != _appMarker ||
        decoded['transactions'] is! List) {
      throw const FormatException('Not an ExpenseManager backup');
    }
    final valid = <TransactionModel>[];
    var invalid = 0;
    for (final item in decoded['transactions'] as List) {
      try {
        final t = TransactionModel.fromJson(item as Map<String, dynamic>);
        valid.add(_sanitize(t));
      } catch (_) {
        invalid++;
      }
    }
    return BackupParseResult(valid: valid, invalidCount: invalid);
  }

  static BackupParseResult _parseCsv(String content) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content.replaceAll('\r\n', '\n'));
    if (rows.isEmpty ||
        rows.first.map((c) => c.toString().trim()).join(',') !=
            csvHeader.join(',')) {
      throw const FormatException('Not an ExpenseManager CSV');
    }
    final valid = <TransactionModel>[];
    var invalid = 0;
    for (final row in rows.skip(1)) {
      if (row.length == 1 && row.first.toString().trim().isEmpty) continue;
      final t = _rowToTransaction(row);
      if (t == null) {
        invalid++;
      } else {
        valid.add(t);
      }
    }
    return BackupParseResult(valid: valid, invalidCount: invalid);
  }

  static TransactionModel? _rowToTransaction(List<dynamic> row) {
    if (row.length != csvHeader.length) return null;
    final cells = row.map((c) => c.toString()).toList();
    final date = DateTime.tryParse(cells[0]);
    final amount = double.tryParse(cells[5]);
    final type = TransactionType.values
        .where((t) => t.name == cells[1])
        .firstOrNull;
    final category = cells[2].trim();
    if (date == null || amount == null || amount <= 0 || type == null ||
        category.isEmpty) {
      return null;
    }
    return TransactionModel(
      id: '',
      userId: '',
      amount: amount,
      type: type,
      category: category,
      subcategory: cells[3].isEmpty ? null : cells[3],
      description: cells[4].isEmpty ? null : cells[4],
      date: date,
      createdAt: clock.now(),
      currency: cells[6].isEmpty ? 'EUR' : cells[6],
    );
  }

  /// id/userId vacíos: el repositorio asigna ids nuevos al insertar, evitando
  /// colisiones de PK al re-importar (el local hace REPLACE silencioso).
  static TransactionModel _sanitize(TransactionModel t) =>
      t.copyWith(id: '', userId: '', recurringTransactionId: null);

  // ── Dedup ──────────────────────────────────────────────────────────────────

  static String _dedupKey(TransactionModel t) => [
        DateFormat('yyyy-MM-dd').format(t.date),
        t.amount.toStringAsFixed(2),
        t.category,
        (t.description ?? '').trim(),
      ].join('|');

  /// Filtra de [incoming] las transacciones que ya existen en [existing]
  /// según (fecha-día, importe, categoría, descripción). También deduplica
  /// dentro del propio archivo importado.
  static List<TransactionModel> dedup(
    List<TransactionModel> incoming,
    List<TransactionModel> existing,
  ) {
    final seen = existing.map(_dedupKey).toSet();
    final result = <TransactionModel>[];
    for (final t in incoming) {
      if (seen.add(_dedupKey(t))) result.add(t);
    }
    return result;
  }
}
