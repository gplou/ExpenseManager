import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:expense_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:expense_manager/features/transactions/data/initial_sync_service.dart';
import 'package:expense_manager/features/transactions/data/local_recurring_transactions_repository.dart';
import 'package:expense_manager/features/transactions/data/local_transactions_repository.dart';
import 'package:expense_manager/features/transactions/domain/recurring_transaction_model.dart';
import 'package:expense_manager/features/transactions/domain/transaction_model.dart';
import 'package:expense_manager/features/transactions/presentation/providers/transactions_provider.dart';

/// Herramienta temporal de recuperación: lee todas las transacciones y
/// transacciones recurrentes guardadas en el SQLite local de este dispositivo
/// para el usuario actual y las sube a Supabase, sin borrar nada localmente.
///
/// Pensada para usuarios que tenían datos en una cuenta FREE y, al pasar a
/// PRO, esos datos quedaron "huérfanos" en local sin sincronizarse a la nube.
class DataRecoveryScreen extends ConsumerStatefulWidget {
  const DataRecoveryScreen({super.key});

  @override
  ConsumerState<DataRecoveryScreen> createState() =>
      _DataRecoveryScreenState();
}

enum _Status { idle, scanning, scanned, uploading, done, error }

class _DataRecoveryScreenState extends ConsumerState<DataRecoveryScreen> {
  _Status _status = _Status.idle;
  List<TransactionModel> _localTransactions = [];
  List<RecurringTransactionModel> _localRecurring = [];
  int _uploadedTransactions = 0;
  int _uploadedRecurring = 0;
  int _failedUploads = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _status = _Status.scanning);

    try {
      final localTx = await LocalTransactionsRepository(userId: user.id)
          .getAllForUser();
      final localRecurring =
          await LocalRecurringTransactionsRepository(userId: user.id)
              .getAllForUser();

      setState(() {
        _localTransactions = localTx;
        _localRecurring = localRecurring;
        _status = _Status.scanned;
      });
    } catch (e) {
      setState(() {
        _status = _Status.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _upload() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _status = _Status.uploading;
      _uploadedTransactions = 0;
      _uploadedRecurring = 0;
      _failedUploads = 0;
    });

    final cloudRecurring = ref.read(cloudRecurringRepoForHydrationProvider);
    final cloudTx = ref.read(cloudTxRepoForHydrationProvider);

    // Recurrentes primero por la dependencia FK desde transactions.
    for (final r in _localRecurring) {
      try {
        await cloudRecurring.upsertRecurring(r);
        _uploadedRecurring++;
      } catch (_) {
        _failedUploads++;
      }
    }

    for (final t in _localTransactions) {
      try {
        await cloudTx.upsertTransaction(t);
        _uploadedTransactions++;
      } catch (_) {
        _failedUploads++;
      }
    }

    ref.invalidate(allTransactionsProvider);

    setState(() => _status = _Status.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar datos locales')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Esta herramienta busca transacciones guardadas en este '
            'dispositivo que no se hayan sincronizado todavía con tu cuenta, '
            'y las sube sin borrar nada localmente.',
          ),
          const SizedBox(height: 24),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_status) {
      case _Status.idle:
      case _Status.scanning:
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(),
          ),
        );

      case _Status.error:
        return Text(
          'Error al leer la base de datos local: $_errorMessage',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );

      case _Status.scanned:
        return _buildScanResult(context);

      case _Status.uploading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Subiendo datos a la nube...'),
              ],
            ),
          ),
        );

      case _Status.done:
        return _buildUploadResult(context);
    }
  }

  Widget _buildScanResult(BuildContext context) {
    final hasData = _localTransactions.isNotEmpty || _localRecurring.isNotEmpty;

    if (!hasData) {
      return const Text(
        'No se han encontrado transacciones locales pendientes de '
        'sincronizar. Tus datos están al día.',
      );
    }

    final dates = _localTransactions.map((t) => t.date).toList()..sort();
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Se han encontrado ${_localTransactions.length} transacciones y '
          '${_localRecurring.length} recurrentes guardadas en este '
          'dispositivo.',
        ),
        if (dates.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Rango de fechas: ${dateFormat.format(dates.first)} - '
            '${dateFormat.format(dates.last)}',
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _upload,
          child: const Text('Subir a la nube'),
        ),
      ],
    );
  }

  Widget _buildUploadResult(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transacciones subidas: $_uploadedTransactions'),
        Text('Recurrentes subidas: $_uploadedRecurring'),
        if (_failedUploads > 0)
          Text(
            'Elementos que fallaron: $_failedUploads (puedes volver a '
            'intentarlo, no se duplicarán)',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        const Text('Tus datos locales no se han modificado ni borrado.'),
      ],
    );
  }
}
