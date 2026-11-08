import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/subscriptions/domain/subscription.dart';
import 'package:gastadoor/features/subscriptions/domain/subscription_totals.dart';

Subscription sub(
  String name,
  int cents, {
  SubscriptionFrequency frequency = SubscriptionFrequency.monthly,
  DateTime? next,
  bool active = true,
}) => Subscription(
  id: name,
  userId: 'u',
  name: name,
  amountCents: cents,
  frequency: frequency,
  firstChargeOn: DateTime(2026, 10, 4),
  nextChargeOn: next ?? DateTime(2026, 12, 4),
  accountId: 'a',
  active: active,
);

void main() {
  const yearly = SubscriptionFrequency.yearly;

  group('cost', () {
    test('a monthly subscription costs 12 times its price a year', () {
      expect(yearlyCostCents(sub('Spotify', 14900)), 178800);
      expect(monthlyCostCents(sub('Spotify', 14900)), 14900);
    });

    test('a yearly subscription is its price divided by 12 a month', () {
      final s = sub('Domain', 120000, frequency: yearly);
      expect(yearlyCostCents(s), 120000);
      expect(monthlyCostCents(s), 10000);
    });

    test('a yearly price rounds to the nearest centavo', () {
      // 100000 / 12 = 8333.33 and 100004 / 12 = 8333.67
      expect(monthlyCostCents(sub('A', 100000, frequency: yearly)), 8333);
      expect(monthlyCostCents(sub('A', 100004, frequency: yearly)), 8334);
    });

    test('totals add up what is not paused', () {
      final all = [
        sub('Spotify', 14900),
        sub('Domain', 120000, frequency: yearly),
        sub('Gym', 50000, active: false),
      ];
      expect(totalYearlyCents(all), 298800); // 14900 * 12 + 120000
      expect(totalMonthlyCents(all), 24900);
    });

    test('the monthly total is rounded once, not once per subscription', () {
      final all = [
        sub('A', 100004, frequency: yearly),
        sub('B', 100004, frequency: yearly),
      ];
      // Each one alone rounds up to 8334 (so 16668 added together), but the
      // real total is 200008 / 12 = 16667.33.
      expect(totalMonthlyCents(all), 16667);
    });

    test('no subscriptions cost nothing', () {
      expect(totalMonthlyCents([]), 0);
      expect(totalYearlyCents([]), 0);
    });
  });

  group('order', () {
    test('soonest first, then by name, paused ones last', () {
      final sorted = sortedByNextCharge([
        sub('Zed', 100, next: DateTime(2026, 12, 10)),
        sub('Paused', 100, next: DateTime(2026, 11, 1), active: false),
        sub('bee', 100, next: DateTime(2026, 12, 4)),
        sub('Ann', 100, next: DateTime(2026, 12, 4)),
      ]);
      expect(sorted.map((s) => s.name), ['Ann', 'bee', 'Zed', 'Paused']);
    });

    test('nextUp is the soonest active one, or null', () {
      expect(
        nextUp([
          sub('Later', 100, next: DateTime(2026, 12, 20)),
          sub('Soon', 100, next: DateTime(2026, 12, 5)),
          sub('Paused', 100, next: DateTime(2026, 11, 1), active: false),
        ])?.name,
        'Soon',
      );
      expect(nextUp([sub('Paused', 100, active: false)]), isNull);
      expect(nextUp([]), isNull);
    });
  });

  group('days', () {
    final today = DateTime(2026, 11, 8);

    test('counts whole days, also backwards', () {
      expect(daysUntil(DateTime(2026, 11, 8), today: today), 0);
      expect(daysUntil(DateTime(2026, 11, 9), today: today), 1);
      expect(daysUntil(DateTime(2026, 12, 4), today: today), 26);
      expect(daysUntil(DateTime(2026, 11, 7), today: today), -1);
    });

    test('time of day does not matter', () {
      expect(
        daysUntil(
          DateTime(2026, 11, 9, 23, 59),
          today: DateTime(2026, 11, 8, 0, 1),
        ),
        1,
      );
    });

    test('a whole month is 30 days even when the clocks change', () {
      // Clocks change in March in many countries; days stay whole.
      expect(daysUntil(DateTime(2026, 3, 31), today: DateTime(2026, 3, 1)), 30);
    });

    test('says today, tomorrow, or in N days', () {
      expect(relativeDay(0), 'today');
      expect(relativeDay(-3), 'today'); // late: added during the next run
      expect(relativeDay(1), 'tomorrow');
      expect(relativeDay(5), 'in 5 days');
    });

    test('the row text has the date and how far away it is', () {
      expect(
        nextChargeText(sub('Spotify', 100), today: today),
        'Dec 4 · in 26 days',
      );
      expect(
        nextChargeText(
          sub('Spotify', 100, next: DateTime(2026, 11, 9)),
          today: today,
        ),
        'Nov 9 · tomorrow',
      );
    });
  });

  group('words', () {
    test('per month and per year', () {
      expect(frequencyUnit(SubscriptionFrequency.monthly), 'per month');
      expect(frequencyUnit(yearly), 'per year');
    });

    test('days that some months lack come with a reminder', () {
      const monthly = SubscriptionFrequency.monthly;
      expect(shortMonthNote(monthly, DateTime(2026, 11, 28)), isNull);
      for (final day in [29, 30, 31]) {
        expect(shortMonthNote(monthly, DateTime(2026, 12, day)), isNotNull);
      }
    });

    test('only Feb 29 needs a reminder for a yearly subscription', () {
      expect(shortMonthNote(yearly, DateTime(2028, 2, 29)), isNotNull);
      expect(shortMonthNote(yearly, DateTime(2026, 1, 31)), isNull);
      expect(shortMonthNote(yearly, DateTime(2026, 2, 28)), isNull);
    });
  });
}
