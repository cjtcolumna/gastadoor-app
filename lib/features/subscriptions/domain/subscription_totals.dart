import 'package:intl/intl.dart';

import 'subscription.dart';

/// What one subscription costs in a year, in cents.
int yearlyCostCents(Subscription s) => switch (s.frequency) {
  SubscriptionFrequency.monthly => s.amountCents * 12,
  SubscriptionFrequency.yearly => s.amountCents,
};

/// What one subscription costs per month, in cents. A yearly one is its price
/// divided by 12, rounded to the nearest centavo (whole-number maths only).
int monthlyCostCents(Subscription s) => (yearlyCostCents(s) + 6) ~/ 12;

/// Only subscriptions that are not paused cost you anything.
Iterable<Subscription> _active(List<Subscription> all) =>
    all.where((s) => s.active);

/// Everything you pay in a year, in cents (paused subscriptions left out).
int totalYearlyCents(List<Subscription> all) =>
    _active(all).fold(0, (sum, s) => sum + yearlyCostCents(s));

/// The yearly total divided by 12, rounded once at the end so that many small
/// roundings do not add up.
int totalMonthlyCents(List<Subscription> all) =>
    (totalYearlyCents(all) + 6) ~/ 12;

/// Next charge first. Paused ones go last, so the list starts with what is
/// coming up. Subscriptions due on the same day are sorted by name.
List<Subscription> sortedByNextCharge(List<Subscription> all) {
  final sorted = [...all];
  sorted.sort((a, b) {
    if (a.active != b.active) return a.active ? -1 : 1;
    final byDate = a.nextChargeOn.compareTo(b.nextChargeOn);
    return byDate != 0
        ? byDate
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

/// The subscription that charges next, or null if none is active.
Subscription? nextUp(List<Subscription> all) =>
    sortedByNextCharge(all).where((s) => s.active).firstOrNull;

/// Whole days from [today] to [date]. Negative if [date] is in the past.
/// Compared as UTC dates so a daylight-saving change can't make a day 23 or
/// 25 hours long and throw the count off by one.
int daysUntil(DateTime date, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final from = DateTime.utc(now.year, now.month, now.day);
  final to = DateTime.utc(date.year, date.month, date.day);
  return to.difference(from).inDays;
}

/// "today", "tomorrow" or "in 5 days". A charge that is already late is still
/// "today": it is added during the next nightly run.
String relativeDay(int days) {
  if (days <= 0) return 'today';
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}

/// The next charge for a list row, e.g. "Dec 4 · in 26 days".
/// [today] can be passed in so tests don't depend on the real clock.
String nextChargeText(Subscription s, {DateTime? today}) {
  final date = DateFormat.MMMd().format(s.nextChargeOn);
  return '$date · ${relativeDay(daysUntil(s.nextChargeOn, today: today))}';
}

/// "per month" or "per year", shown next to the price.
String frequencyUnit(SubscriptionFrequency f) => switch (f) {
  SubscriptionFrequency.monthly => 'per month',
  SubscriptionFrequency.yearly => 'per year',
};

/// A short reminder for days that don't exist in every month, or null when
/// the picked [date] is safe. Postgres moves such a charge to the last day.
String? shortMonthNote(SubscriptionFrequency f, DateTime date) {
  switch (f) {
    case SubscriptionFrequency.monthly:
      if (date.day < 29) return null;
      return 'In months with fewer days, it is charged on the last day.';
    case SubscriptionFrequency.yearly:
      if (date.month != 2 || date.day != 29) return null;
      return 'In years without a Feb 29, it is charged on Feb 28.';
  }
}
