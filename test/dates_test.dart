import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/utils/dates.dart';

void main() {
  test('toDbDate pads month and day', () {
    expect(toDbDate(DateTime(2026, 3, 7)), '2026-03-07');
    expect(toDbDate(DateTime(2026, 10, 22, 23, 59)), '2026-10-22');
  });

  test('friendlyDate says Today, Yesterday, or a short date', () {
    final today = DateTime(2026, 10, 22, 15, 30);
    expect(friendlyDate(DateTime(2026, 10, 22, 8), today: today), 'Today');
    expect(friendlyDate(DateTime(2026, 10, 21), today: today), 'Yesterday');
    expect(friendlyDate(DateTime(2026, 10, 1), today: today), 'Oct 1, 2026');
    expect(friendlyDate(DateTime(2025, 12, 31), today: today), 'Dec 31, 2025');
  });
}
