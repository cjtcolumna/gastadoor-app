import '../../../core/utils/money.dart';

/// How full a sub-account's ring is: 0.0 (empty) to 1.0 (goal reached).
///
/// No goal, or a balance at or below zero, gives 0. Saving more than the
/// goal still gives 1.0, so the ring never goes past full.
double goalProgress(int balanceCents, int? goalCents) {
  if (goalCents == null || goalCents <= 0 || balanceCents <= 0) return 0;
  if (balanceCents >= goalCents) return 1;
  return balanceCents / goalCents;
}

/// True when the balance has reached a goal that was set.
bool goalReached(int balanceCents, int? goalCents) =>
    goalCents != null && goalCents > 0 && balanceCents >= goalCents;

/// The line under a bubble: "35% of ₱20,000", "Goal reached", or
/// "No goal". Percentages round down, so 99.9% never shows as 100%.
String goalText(int balanceCents, int? goalCents) {
  if (goalCents == null || goalCents <= 0) return 'No goal';
  if (goalReached(balanceCents, goalCents)) return 'Goal reached';
  final percent = (goalProgress(balanceCents, goalCents) * 100).floor();
  return '$percent% of ${wholeAmount(goalCents)}';
}

/// Like Money.format, but leaves off ".00" for whole pesos:
/// 2000000 -> "₱20,000", and 2050050 -> "₱20,500.50".
String wholeAmount(int cents) {
  final text = Money.format(cents);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}
