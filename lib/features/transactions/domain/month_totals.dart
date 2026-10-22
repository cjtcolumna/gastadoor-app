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
      switch (t.kind) {
        case TransactionKind.income:
          income += t.amountCents;
        case TransactionKind.expense:
          expense += t.amountCents;
        case TransactionKind.transfer:
          // Moving money between your own accounts isn't income or spending.
          break;
      }
    }
    return MonthTotals(incomeCents: income, expenseCents: expense);
  }

  final int incomeCents;
  final int expenseCents;
}
