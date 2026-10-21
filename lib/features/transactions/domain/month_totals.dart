import 'transaction.dart';

/// How much came in and went out over a period, in cents.
class MonthTotals {
  const MonthTotals({required this.incomeCents, required this.expenseCents});

  static const zero = MonthTotals(incomeCents: 0, expenseCents: 0);

  /// Adds up a list of transactions into income and expense totals.
  factory MonthTotals.from(List<Transaction> transactions) {
    var income = 0;
    var expense = 0;
    for (final t in transactions) {
      if (t.kind == TransactionKind.income) {
        income += t.amountCents;
      } else {
        expense += t.amountCents;
      }
    }
    return MonthTotals(incomeCents: income, expenseCents: expense);
  }

  final int incomeCents;
  final int expenseCents;
}
