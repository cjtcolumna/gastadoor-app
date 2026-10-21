import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget.freezed.dart';
part 'budget.g.dart';

enum BudgetPeriod { weekly, monthly, yearly }

@freezed
abstract class Budget with _$Budget {
  const factory Budget({
    required String id,
    required String userId,

    /// Null means an overall budget across all expense categories.
    String? categoryId,
    required String name,
    @Default(BudgetPeriod.monthly) BudgetPeriod period,
    required int amountCents,
    required DateTime startsOn,
    DateTime? createdAt,
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);
}
