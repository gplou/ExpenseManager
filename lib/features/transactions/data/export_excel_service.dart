import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/transaction_categories.dart';
import '../domain/transaction_model.dart';

class ExportExcelService {
  static Future<void> exportTransactions(
    List<TransactionModel> transactions,
    AppLocalizations l10n,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Transacciones'];
    excel.delete('Sheet1');

    // Header style
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#4A9E8A'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // Headers
    final headers = [
      l10n.exportColumnDate,
      l10n.exportColumnType,
      l10n.exportColumnCategory,
      l10n.exportColumnDescription,
      l10n.exportColumnAmount,
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Set column widths
    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 30);
    sheet.setColumnWidth(4, 14);

    // Data rows (sorted by date desc, matching the UI)
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    final dateFmt = DateFormat('dd/MM/yyyy');

    for (var i = 0; i < sorted.length; i++) {
      final t = sorted[i];
      final rowIndex = i + 1;
      final isIncome = t.type.isIncome;
      final sign = isIncome ? 1.0 : -1.0;

      final rowStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString(
          rowIndex.isEven ? '#F5F5F5' : '#FFFFFF',
        ),
      );

      void setCell(int col, CellValue value) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        cell.value = value;
        cell.cellStyle = rowStyle;
      }

      setCell(0, TextCellValue(dateFmt.format(t.date)));
      setCell(1, TextCellValue(t.type.l10nLabel(l10n)));
      setCell(2, TextCellValue(TransactionCategories.localizedName(t.category, l10n)));
      setCell(3, TextCellValue(t.description ?? ''));
      setCell(4, DoubleCellValue(t.amount * sign));
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Could not encode Excel file');

    final fileName = 'ExpenseManager_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';

    // Save to temp dir then open system share sheet
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(Uint8List.fromList(bytes));

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: fileName,
    );
  }
}
