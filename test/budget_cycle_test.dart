import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/budgets/domain/budget_cycle.dart';

void main() {
  group('monthly cycle', () {
    test('starting on the 1st is the calendar month', () {
      final p = BudgetCycle.calendarMonth.periodAt(DateTime(2026, 10, 17));
      expect(p.start, DateTime(2026, 10, 1));
      expect(p.end, DateTime(2026, 10, 31));
    });

    test('the first and last day of a period belong to it', () {
      const cycle = BudgetCycle(firstDay: 25);
      expect(
        cycle.periodAt(DateTime(2026, 10, 25)).start,
        DateTime(2026, 10, 25),
      );
      expect(
        cycle.periodAt(DateTime(2026, 11, 24)).end,
        DateTime(2026, 11, 24),
      );
      // The day after starts a new period.
      expect(
        cycle.periodAt(DateTime(2026, 11, 25)).start,
        DateTime(2026, 11, 25),
      );
    });

    test('a salary month runs from the 25th to the 24th', () {
      const cycle = BudgetCycle(firstDay: 25);
      final p = cycle.periodAt(DateTime(2026, 11, 3));
      expect(p.start, DateTime(2026, 10, 25));
      expect(p.end, DateTime(2026, 11, 24));
    });

    test('crosses the new year', () {
      const cycle = BudgetCycle(firstDay: 20);
      final p = cycle.periodAt(DateTime(2027, 1, 5));
      expect(p.start, DateTime(2026, 12, 20));
      expect(p.end, DateTime(2027, 1, 19));
    });

    test('a late day uses the last day of a short month', () {
      const cycle = BudgetCycle(firstDay: 30);
      // February 2027 has 28 days, so the period starts on the 28th.
      final p = cycle.periodAt(DateTime(2027, 2, 28));
      expect(p.start, DateTime(2027, 2, 28));
      expect(p.end, DateTime(2027, 3, 29));
    });
  });

  group('twice a month', () {
    const cycle = BudgetCycle(
      type: BudgetCycleType.twiceMonthly,
      firstDay: 15,
      secondDay: lastDayOfMonth,
    );

    test('15th and last day: the first half', () {
      final p = cycle.periodAt(DateTime(2026, 10, 20));
      expect(p.start, DateTime(2026, 10, 15));
      expect(p.end, DateTime(2026, 10, 30));
    });

    test('15th and last day: the second half rolls into next month', () {
      final p = cycle.periodAt(DateTime(2026, 10, 31));
      expect(p.start, DateTime(2026, 10, 31));
      expect(p.end, DateTime(2026, 11, 14));
      expect(
        cycle.periodAt(DateTime(2026, 11, 2)).start,
        DateTime(2026, 10, 31),
      );
    });

    test('the order of the two days does not matter', () {
      const swapped = BudgetCycle(
        type: BudgetCycleType.twiceMonthly,
        firstDay: lastDayOfMonth,
        secondDay: 15,
      );
      for (final day in [
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 31),
      ]) {
        expect(swapped.periodAt(day), cycle.periodAt(day));
      }
    });

    test('February: the last day is the 28th, and no period is skipped', () {
      final p = cycle.periodAt(DateTime(2027, 2, 28));
      expect(p.start, DateTime(2027, 2, 28));
      expect(p.end, DateTime(2027, 3, 14));
    });

    test('1st and 16th split the month in two', () {
      const c = BudgetCycle(
        type: BudgetCycleType.twiceMonthly,
        firstDay: 1,
        secondDay: 16,
      );
      final p = c.periodAt(DateTime(2026, 10, 9));
      expect(p.start, DateTime(2026, 10, 1));
      expect(p.end, DateTime(2026, 10, 15));
    });

    test('every day belongs to exactly one period, with no gaps', () {
      var day = DateTime(2026, 10, 1);
      var period = cycle.periodAt(day);
      for (var i = 0; i < 400; i++) {
        final next = DateTime(day.year, day.month, day.day + 1);
        final nextPeriod = cycle.periodAt(next);
        if (nextPeriod == period) {
          expect(next.isAfter(period.end), isFalse);
        } else {
          // A new period begins the day after the old one ended.
          expect(
            next,
            DateTime(period.end.year, period.end.month, period.end.day + 1),
          );
          expect(nextPeriod.start, next);
        }
        day = next;
        period = nextPeriod;
      }
    });
  });

  group('saving and describing', () {
    test('a monthly cycle saves no second day', () {
      const c = BudgetCycle(firstDay: 5, secondDay: 20);
      expect(c.toRow(), {
        'cycle': 'monthly',
        'first_day': 5,
        'second_day': null,
      });
    });

    test('a row turns back into the same cycle', () {
      const c = BudgetCycle(
        type: BudgetCycleType.twiceMonthly,
        firstDay: 15,
        secondDay: 31,
      );
      expect(BudgetCycle.fromRow(c.toRow()), c);
    });

    test('twice a month needs two different days', () {
      expect(
        const BudgetCycle(
          type: BudgetCycleType.twiceMonthly,
          firstDay: 10,
          secondDay: 10,
        ).isValid,
        isFalse,
      );
      expect(
        const BudgetCycle(
          type: BudgetCycleType.twiceMonthly,
          firstDay: 10,
        ).isValid,
        isFalse,
      );
      expect(BudgetCycle.calendarMonth.isValid, isTrue);
    });

    test('day labels', () {
      expect([1, 2, 3, 4, 11, 12, 13, 15, 21, 22, 23, 30, 31].map(dayLabel), [
        '1st',
        '2nd',
        '3rd',
        '4th',
        '11th',
        '12th',
        '13th',
        '15th',
        '21st',
        '22nd',
        '23rd',
        '30th',
        'last day',
      ]);
    });

    test('summary', () {
      expect(BudgetCycle.calendarMonth.summary, 'Monthly · 1st');
      expect(
        const BudgetCycle(
          type: BudgetCycleType.twiceMonthly,
          firstDay: 15,
          secondDay: 31,
        ).summary,
        'Twice a month · 15th & last day',
      );
    });

    test('a whole calendar month is labeled by its name, others by dates', () {
      expect(
        periodLabel(
          BudgetPeriod(
            start: DateTime(2026, 10, 1),
            end: DateTime(2026, 10, 31),
          ),
        ),
        'October',
      );
      expect(
        periodLabel(
          BudgetPeriod(
            start: DateTime(2026, 10, 15),
            end: DateTime(2026, 10, 30),
          ),
        ),
        'Oct 15 – Oct 30',
      );
    });

    test('a period with no end yet is "Since ..."', () {
      final open = BudgetPeriod(
        start: DateTime(2026, 10, 15),
        end: DateTime(2026, 10, 20),
        isOpen: true,
      );
      expect(periodLabel(open), 'Since Oct 15');
      expect(periodPhrase(open), 'since Oct 15');
      expect(
        periodPhrase(
          BudgetPeriod(
            start: DateTime(2026, 10, 1),
            end: DateTime(2026, 10, 31),
          ),
        ),
        'for October',
      );
    });
  });

  group('salary cycle', () {
    const cycle = BudgetCycle(type: BudgetCycleType.salary);
    final today = DateTime(2026, 11, 12);

    test('starts on the day of the latest salary and has no end yet', () {
      final p = cycle.salaryPeriod(today, [
        DateTime(2026, 10, 30),
        DateTime(2026, 11, 5),
        DateTime(2026, 10, 15),
      ]);
      expect(p.start, DateTime(2026, 11, 5));
      expect(p.end, today); // the end is today, until the next salary
      expect(p.isOpen, isTrue);
    });

    test('every salary starts a new round, even a few days after another', () {
      final p = cycle.salaryPeriod(today, [
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 8),
      ]);
      expect(p.start, DateTime(2026, 11, 10));
    });

    test('a salary logged today starts today', () {
      final p = cycle.salaryPeriod(today, [DateTime(2026, 11, 12, 18, 30)]);
      expect(p.start, today);
      expect(p.end, today);
    });

    test('a salary dated in the future does not count yet', () {
      final p = cycle.salaryPeriod(today, [
        DateTime(2026, 11, 30),
        DateTime(2026, 11, 1),
      ]);
      expect(p.start, DateTime(2026, 11, 1));
    });

    test('with no salary yet it is the calendar month', () {
      final none = cycle.salaryPeriod(today, const []);
      expect(none.start, DateTime(2026, 11, 1));
      expect(none.end, DateTime(2026, 11, 30));
      expect(none.isOpen, isFalse);

      // Only future salaries: still none that counts.
      expect(
        cycle.salaryPeriod(today, [DateTime(2026, 12, 1)]).start,
        DateTime(2026, 11, 1),
      );
    });

    test('periodAt on a salary cycle is the calendar month too', () {
      expect(cycle.periodAt(today), cycle.salaryPeriod(today, const []));
    });

    test('saves as "salary" with no second day', () {
      expect(cycle.toRow(), {
        'cycle': 'salary',
        'first_day': 1,
        'second_day': null,
      });
      expect(BudgetCycle.fromRow(cycle.toRow()), cycle);
      expect(cycle.isValid, isTrue);
      expect(cycle.summary, 'When I log my salary');
    });
  });
}
