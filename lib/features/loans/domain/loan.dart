import 'package:freezed_annotation/freezed_annotation.dart';

part 'loan.freezed.dart';
part 'loan.g.dart';

/// Money you lent to someone. It is not spending: it is money you expect back.
@freezed
abstract class Loan with _$Loan {
  const factory Loan({
    required String id,
    required String userId,

    /// Who borrowed the money.
    required String person,

    /// How much was lent, in cents.
    required int amountCents,
    required DateTime lentOn,

    /// When it should be paid back. Null = no due date.
    DateTime? dueOn,
    String? note,

    /// The account the money left. Null = no account was changed (for a loan
    /// made before you started tracking).
    String? accountId,
    DateTime? createdAt,
  }) = _Loan;

  factory Loan.fromJson(Map<String, dynamic> json) => _$LoanFromJson(json);
}

/// Money paid back toward a [Loan].
@freezed
abstract class LoanPayment with _$LoanPayment {
  const factory LoanPayment({
    required String id,
    required String userId,
    required String loanId,
    required int amountCents,
    required DateTime paidOn,
    String? note,

    /// The account the money went into. Null = no account was changed.
    String? accountId,
    DateTime? createdAt,
  }) = _LoanPayment;

  factory LoanPayment.fromJson(Map<String, dynamic> json) =>
      _$LoanPaymentFromJson(json);
}
