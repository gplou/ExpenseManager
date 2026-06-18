import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget_model.freezed.dart';
part 'budget_model.g.dart';

/// Presupuesto mensual por categoría de gasto.
///
/// `period` es 'monthly' fijo en v1 (el campo existe para no migrar schema si
/// se añaden otros periodos). `currency` hereda la divisa global al crear y es
/// display-only: no hay conversión, igual que en [TransactionModel].
@freezed
abstract class BudgetModel with _$BudgetModel {
  const factory BudgetModel({
    required String id,
    required String userId,
    required String category,
    required double amount,
    @Default('monthly') String period,
    @Default('EUR') String currency,
    required DateTime createdAt,
  }) = _BudgetModel;

  factory BudgetModel.fromJson(Map<String, dynamic> json) =>
      _$BudgetModelFromJson(json);
}
