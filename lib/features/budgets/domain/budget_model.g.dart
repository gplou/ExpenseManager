// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BudgetModel _$BudgetModelFromJson(Map<String, dynamic> json) => _BudgetModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      period: json['period'] as String? ?? 'monthly',
      currency: json['currency'] as String? ?? 'EUR',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$BudgetModelToJson(_BudgetModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'category': instance.category,
      'amount': instance.amount,
      'period': instance.period,
      'currency': instance.currency,
      'createdAt': instance.createdAt.toIso8601String(),
    };
