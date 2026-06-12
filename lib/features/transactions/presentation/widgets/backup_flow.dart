import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:expense_manager/core/services/analytics_service.dart';
import 'package:expense_manager/core/theme/app_spacing.dart';
import 'package:expense_manager/core/utils/app_logger.dart';
import 'package:expense_manager/core/utils/extensions.dart';
import 'package:expense_manager/features/transactions/data/backup_service.dart';
import 'package:expense_manager/features/transactions/data/recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:expense_manager/l10n/app_localizations.dart';

/// Rango "todas las transacciones" para export y dedup de import.
final _allTimeFrom = DateTime(2000);
final _allTimeTo = DateTime(2100);

// ── Export ────────────────────────────────────────────────────────────────────

/// Sheet de elección de formato (JSON completo / CSV simple) y export con la
/// hoja de compartir del sistema.
Future<void> runBackupExportFlow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final format = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(l10n.backupExport, style: ctx.textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.data_object_rounded),
              title: Text(l10n.backupExportJson),
              onTap: () => Navigator.pop(ctx, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(l10n.backupExportCsv),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
          ],
        ),
      ),
    ),
  );
  if (format == null || !context.mounted) return;

  try {
    final txRepo = ref.read(transactionsRepositoryProvider);
    final transactions =
        await txRepo.getTransactions(from: _allTimeFrom, to: _allTimeTo);
    if (format == 'json') {
      final recurring = await ref
          .read(recurringTransactionsRepositoryProvider)
          .getAllForUser();
      await BackupService.exportJson(transactions, recurring);
    } else {
      await BackupService.exportCsv(transactions);
    }
    AnalyticsService.track(AnalyticsService.backupExported, {
      'format': format,
      'count': transactions.length,
    });
  } catch (e) {
    AppLogger.log('[Backup] export failed: $e');
    if (context.mounted) {
      context.showSnackbar(l10n.exportError, isError: true);
    }
  }
}

// ── Import ────────────────────────────────────────────────────────────────────

/// file_picker → parser del formato propio → preview con recuento
/// (nuevas / duplicadas / erróneas) → insert vía transactionsRepository.
Future<void> runBackupImportFlow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);

  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json', 'csv'],
    withData: true,
  );
  final bytes = picked?.files.single.bytes;
  if (bytes == null || !context.mounted) return;

  final BackupParseResult parsed;
  final List<TransactionModel> toImport;
  try {
    parsed = BackupService.parse(utf8.decode(bytes));
    final existing = await ref
        .read(transactionsRepositoryProvider)
        .getTransactions(from: _allTimeFrom, to: _allTimeTo);
    toImport = BackupService.dedup(parsed.valid, existing);
  } catch (e) {
    AppLogger.log('[Backup] import parse failed: $e');
    if (context.mounted) {
      context.showSnackbar(l10n.backupImportError, isError: true);
    }
    return;
  }
  if (!context.mounted) return;

  if (toImport.isEmpty) {
    context.showSnackbar(l10n.backupImportNothing);
    return;
  }

  final duplicates = parsed.valid.length - toImport.length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.backupImport),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.backupImportPreview(
            toImport.length,
            duplicates,
            parsed.invalidCount,
          )),
          const Gap(8),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.backupImport),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final repo = ref.read(transactionsRepositoryProvider);
    for (final t in toImport) {
      await repo.createTransaction(t);
    }
    // Una sola invalidación al final: los derivados se reconstruyen una vez.
    ref.invalidate(allTransactionsProvider);
    AnalyticsService.track(AnalyticsService.backupImported, {
      'count': toImport.length,
    });
    if (context.mounted) {
      context.showSnackbar(l10n.backupImportDone(toImport.length));
    }
  } catch (e) {
    AppLogger.log('[Backup] import insert failed: $e');
    // Refleja lo que sí llegó a insertarse antes del fallo.
    ref.invalidate(allTransactionsProvider);
    if (context.mounted) {
      context.showSnackbar(l10n.backupImportError, isError: true);
    }
  }
}
