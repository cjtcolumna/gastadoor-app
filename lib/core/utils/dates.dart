/// Turns a date into the 'YYYY-MM-DD' text Postgres uses for `date` columns.
String toDbDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The date part only (midnight), so "today" compares equal all day long.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Yesterday", or a short date like "Oct 20, 2026".
/// [today] can be passed in so tests don't depend on the real clock.
String friendlyDate(DateTime date, {DateTime? today}) {
  final day = dateOnly(date);
  final now = dateOnly(today ?? DateTime.now());
  if (day == now) return 'Today';
  if (day == now.subtract(const Duration(days: 1))) return 'Yesterday';
  final month = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][day.month - 1];
  return '$month ${day.day}, ${day.year}';
}
