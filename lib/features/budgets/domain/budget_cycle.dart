import 'package:intl/intl.dart';

/// How often budgets start over.
enum BudgetCycleType {
  /// One period a month, starting on [BudgetCycle.firstDay].
  monthly('monthly'),

  /// Two periods a month, starting on [BudgetCycle.firstDay] and
  /// [BudgetCycle.secondDay].
  twiceMonthly('twice_monthly'),

  /// A new period starts every time the user logs their salary.
  salary('salary');

  const BudgetCycleType(this.dbValue);

  /// The text stored in the `budget_settings.cycle` column.
  final String dbValue;

  static BudgetCycleType fromDb(String? value) => values.firstWhere(
    (t) => t.dbValue == value,
    orElse: () => BudgetCycleType.monthly,
  );
}

/// One budget period: from [start] to [end], both days included.
/// Compares by value, so it works as a provider key.
class BudgetPeriod {
  const BudgetPeriod({
    required this.start,
    required this.end,
    this.isOpen = false,
  });

  final DateTime start;
  final DateTime end;

  /// True when the period has no planned end (it lasts until the next
  /// salary), so [end] is just today.
  final bool isOpen;

  @override
  bool operator ==(Object other) =>
      other is BudgetPeriod &&
      other.start == start &&
      other.end == end &&
      other.isOpen == isOpen;

  @override
  int get hashCode => Object.hash(start, end, isOpen);

  @override
  String toString() => 'BudgetPeriod($start – $end${isOpen ? ', open' : ''})';
}

/// The day number that means "the last day of the month".
const lastDayOfMonth = 31;

/// When budgets start over: every month on one day, or twice a month.
///
/// A day from 1 to 31. In a month that is too short (day 30 in February),
/// the period starts on that month's last day instead.
class BudgetCycle {
  const BudgetCycle({
    this.type = BudgetCycleType.monthly,
    this.firstDay = 1,
    this.secondDay,
  });

  /// The plain calendar month: a new period on the 1st. Used until the user
  /// chooses something else.
  static const calendarMonth = BudgetCycle();

  final BudgetCycleType type;
  final int firstDay;

  /// Only used when [type] is [BudgetCycleType.twiceMonthly].
  final int? secondDay;

  /// A cycle from a `budget_settings` row.
  factory BudgetCycle.fromRow(Map<String, dynamic> row) => BudgetCycle(
    type: BudgetCycleType.fromDb(row['cycle'] as String?),
    firstDay: (row['first_day'] as num?)?.toInt() ?? 1,
    secondDay: (row['second_day'] as num?)?.toInt(),
  );

  /// The columns to save. A monthly cycle has no second day.
  Map<String, dynamic> toRow() => {
    'cycle': type.dbValue,
    'first_day': firstDay,
    'second_day': type == BudgetCycleType.twiceMonthly ? secondDay : null,
  };

  bool get isTwiceMonthly => type == BudgetCycleType.twiceMonthly;
  bool get isSalary => type == BudgetCycleType.salary;

  /// False when twice a month has no second day, or both days are the same.
  bool get isValid =>
      !isTwiceMonthly || (secondDay != null && secondDay != firstDay);

  /// The days a period starts on, in a month. (The salary cycle has no
  /// fixed days; until a salary is logged it acts like the calendar month.)
  List<int> get _startDays => [
    isSalary ? 1 : firstDay,
    if (isTwiceMonthly && secondDay != null) secondDay!,
  ];

  /// The period for the salary cycle: it starts on the day of your latest
  /// salary ([salaryDates]) and has no end yet. Salaries dated after [today]
  /// don't count. With no salary yet, it is the calendar month.
  BudgetPeriod salaryPeriod(DateTime today, List<DateTime> salaryDates) {
    final day = DateTime(today.year, today.month, today.day);
    DateTime? latest;
    for (final d in salaryDates) {
      final date = DateTime(d.year, d.month, d.day);
      if (date.isAfter(day)) continue;
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    if (latest == null) return periodAt(today);
    return BudgetPeriod(start: latest, end: day, isOpen: true);
  }

  /// The period that [date] falls in.
  ///
  /// Lists every start date from last month to next month, takes the latest
  /// one on or before [date] as the start, and the day before the next one
  /// as the end.
  BudgetPeriod periodAt(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final starts = <DateTime>{
      for (final monthOffset in [-1, 0, 1])
        for (final d in _startDays)
          _startIn(date.year, date.month + monthOffset, d),
    }.toList()..sort();

    final start = starts.lastWhere((s) => !s.isAfter(day));
    final nextStart = starts.firstWhere((s) => s.isAfter(day));
    return BudgetPeriod(
      start: start,
      end: DateTime(nextStart.year, nextStart.month, nextStart.day - 1),
    );
  }

  /// [day] in the given month, or that month's last day if it is too short.
  /// Months outside 1–12 roll over into the neighbouring year.
  static DateTime _startIn(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  /// A short description, e.g. "Monthly · 1st" or "Twice a month · 15th & last day".
  String get summary {
    if (isSalary) return 'When I log my salary';
    if (isTwiceMonthly && secondDay != null) {
      return 'Twice a month · ${dayLabel(firstDay)} & ${dayLabel(secondDay!)}';
    }
    return 'Monthly · ${dayLabel(firstDay)}';
  }

  @override
  bool operator ==(Object other) =>
      other is BudgetCycle &&
      other.type == type &&
      other.firstDay == firstDay &&
      other.secondDay == secondDay;

  @override
  int get hashCode => Object.hash(type, firstDay, secondDay);
}

/// "1st", "2nd", "3rd", "15th", or "last day" for 31.
String dayLabel(int day) {
  if (day == lastDayOfMonth) return 'last day';
  final lastDigit = day % 10;
  final teen = day >= 11 && day <= 13;
  final suffix = teen
      ? 'th'
      : switch (lastDigit) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$day$suffix';
}

/// A name for a period. A whole calendar month is just its name ("October");
/// one with no end yet is "Since Oct 15"; anything else shows its dates
/// ("Oct 15 – Oct 29").
String periodLabel(BudgetPeriod period) {
  final start = period.start;
  final end = period.end;
  if (period.isOpen) return 'Since ${DateFormat.MMMd().format(start)}';
  final wholeMonth =
      start.day == 1 &&
      start.year == end.year &&
      start.month == end.month &&
      end.day == DateTime(end.year, end.month + 1, 0).day;
  if (wholeMonth) return DateFormat.MMMM().format(start);
  final format = DateFormat.MMMd();
  return '${format.format(start)} – ${format.format(end)}';
}

/// The period in a sentence: "for October", "for Oct 15 – Oct 29", or
/// "since Oct 15".
String periodPhrase(BudgetPeriod period) => period.isOpen
    ? 'since ${DateFormat.MMMd().format(period.start)}'
    : 'for ${periodLabel(period)}';

/// Days left in [period], counting [today] itself, so the last day is 1.
/// Null for a period with no planned end (it lasts until the next salary).
/// 0 once the period is over.
int? daysLeftIn(BudgetPeriod period, DateTime today) {
  if (period.isOpen) return null;
  // Compare as UTC dates so a daylight-saving change can't make a day 23
  // or 25 hours long and throw the count off by one.
  final last = DateTime.utc(period.end.year, period.end.month, period.end.day);
  final now = DateTime.utc(today.year, today.month, today.day);
  final days = last.difference(now).inDays + 1;
  return days < 0 ? 0 : days;
}

/// "12 days left" or "1 day left".
String daysLeftText(int days) => days == 1 ? '1 day left' : '$days days left';
