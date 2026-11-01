import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/utils/money.dart';

void main() {
  group('Money.parseToCents', () {
    test('parses whole and fractional amounts', () {
      expect(Money.parseToCents('12'), 1200);
      expect(Money.parseToCents('12.5'), 1250);
      expect(Money.parseToCents('1,234.56'), 123456);
      expect(Money.parseToCents('-3.10'), -310);
    });

    test('toInputText round-trips through parseToCents', () {
      expect(Money.toInputText(0), '0.00');
      expect(Money.toInputText(5), '0.05');
      expect(Money.toInputText(123450), '1234.50');
      expect(Money.toInputText(-310), '-3.10');
      for (final cents in [0, 1, 99, 100, 123456, -4999]) {
        expect(Money.parseToCents(Money.toInputText(cents)), cents);
      }
    });

    test('rejects invalid input', () {
      expect(Money.parseToCents(''), isNull);
      expect(Money.parseToCents('1.234'), isNull);
      expect(Money.parseToCents('abc'), isNull);
      expect(Money.parseToCents('-'), isNull);
      expect(Money.parseToCents('.'), isNull);
      expect(Money.parseToCents('-.'), isNull);
      expect(Money.parseToCents('.5'), 50);
    });
  });

  group('Money.formatShort (tiny amounts for pills)', () {
    test('under 1,000 shows whole pesos', () {
      expect(Money.formatShort(0), '₱0');
      expect(Money.formatShort(85000), '₱850');
      expect(Money.formatShort(99999), '₱999'); // ₱999.99, cut not rounded
    });

    test('thousands use k, with at most 3 digits in total', () {
      expect(Money.formatShort(100000), '₱1k');
      expect(Money.formatShort(150000), '₱1.5k');
      expect(Money.formatShort(200000), '₱2k');
      expect(Money.formatShort(105000), '₱1.05k');
      expect(Money.formatShort(123400), '₱1.23k');
      expect(Money.formatShort(1050000), '₱10.5k');
      expect(Money.formatShort(1234500), '₱12.3k');
      expect(Money.formatShort(10500000), '₱105k');
      expect(Money.formatShort(99999900), '₱999k');
    });

    test('millions use m', () {
      expect(Money.formatShort(100000000), '₱1m');
      expect(Money.formatShort(120000000), '₱1.2m');
      expect(Money.formatShort(1050000000), '₱10.5m');
    });

    test('never rounds up and treats negatives as zero', () {
      expect(Money.formatShort(149999), '₱1.49k'); // not 1.5k
      expect(Money.formatShort(-500), '₱0');
    });
  });
}
