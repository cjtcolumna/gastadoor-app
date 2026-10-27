import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/accounts/domain/pocket_goal.dart';

void main() {
  group('goalProgress (how full the ring is)', () {
    test('₱7,000 of ₱20,000 is 35%', () {
      expect(goalProgress(700000, 2000000), closeTo(0.35, 1e-9));
    });

    test('no goal means an empty ring', () {
      expect(goalProgress(700000, null), 0);
    });

    test('zero or negative balance means an empty ring', () {
      expect(goalProgress(0, 2000000), 0);
      expect(goalProgress(-5000, 2000000), 0);
    });

    test('saving more than the goal stops at full', () {
      expect(goalProgress(2500000, 2000000), 1);
      expect(goalProgress(2000000, 2000000), 1);
    });
  });

  group('goalText (the line under the bubble)', () {
    test('shows the percent and the goal', () {
      expect(goalText(700000, 2000000), '35% of ₱20,000');
    });

    test('rounds down, so almost there is never "100%"', () {
      expect(goalText(1999900, 2000000), '99% of ₱20,000');
    });

    test('keeps centavos in the goal when there are some', () {
      expect(goalText(0, 2050050), '0% of ₱20,500.50');
    });

    test('says when the goal is reached or not set', () {
      expect(goalText(2000000, 2000000), 'Goal reached');
      expect(goalText(700000, null), 'No goal');
    });
  });
}
