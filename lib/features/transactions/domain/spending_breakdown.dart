import 'month_totals.dart';
import 'transaction.dart';

/// How much was spent in one category (or in "Other": several small ones).
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.cents,
    this.isOther = false,
  });

  /// null means expenses with no category ("Uncategorized"),
  /// unless [isOther] is true.
  final String? categoryId;
  final int cents;

  /// True for the combined "Other" slice made by [topWithOther].
  final bool isOther;
}

/// Adds up expenses per category, biggest first.
/// Only expenses count: income and transfers are skipped.
List<CategorySlice> spendingByCategory(List<Transaction> transactions) {
  final totals = <String?, int>{};
  for (final t in transactions) {
    if (t.kind != TransactionKind.expense) continue;
    totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amountCents;
  }
  final slices = [
    for (final MapEntry(key: id, value: cents) in totals.entries)
      CategorySlice(categoryId: id, cents: cents),
  ];
  slices.sort((a, b) => b.cents.compareTo(a.cents));
  return slices;
}

/// Keeps the [max] biggest slices and folds the rest into one "Other",
/// so a chart never needs more than [max] + 1 colors.
List<CategorySlice> topWithOther(List<CategorySlice> slices, {int max = 5}) {
  // Folding a single leftover slice into "Other" would just hide its name.
  if (slices.length <= max + 1) return slices;
  final rest = slices.skip(max).fold<int>(0, (sum, s) => sum + s.cents);
  return [
    ...slices.take(max),
    CategorySlice(categoryId: null, cents: rest, isOther: true),
  ];
}

/// One month on the trend chart: its first day and its totals.
typedef MonthPoint = ({DateTime month, MonthTotals totals});

/// Income and spending for each of the [months] months ending with
/// [lastMonth] (oldest first). Months with nothing in them show zeros.
List<MonthPoint> monthlyTrend(
  List<Transaction> transactions, {
  required DateTime lastMonth,
  int months = 6,
}) {
  final firsts = [
    for (var i = months - 1; i >= 0; i--)
      DateTime(lastMonth.year, lastMonth.month - i),
  ];
  return [
    for (final first in firsts)
      (
        month: first,
        totals: MonthTotals.from([
          for (final t in transactions)
            if (t.occurredOn.year == first.year &&
                t.occurredOn.month == first.month)
              t,
        ]),
      ),
  ];
}
