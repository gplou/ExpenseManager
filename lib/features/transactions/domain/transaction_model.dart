import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../l10n/app_localizations.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

enum TransactionType {
  income,
  expense;

  bool get isIncome => this == TransactionType.income;
  bool get isExpense => this == TransactionType.expense;

  String get label => isIncome ? 'Ingreso' : 'Gasto';

  String l10nLabel(AppLocalizations l10n) =>
      isIncome ? l10n.typeIncome : l10n.typeExpense;
}

@freezed
class TransactionModel with _$TransactionModel {
  const factory TransactionModel({
    required String id,
    required String userId,
    required double amount,
    required TransactionType type,
    required String category,
    String? description,
    required DateTime date,
    required DateTime createdAt,
    String? recurringTransactionId,
  }) = _TransactionModel;

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      _$TransactionModelFromJson(json);
}
