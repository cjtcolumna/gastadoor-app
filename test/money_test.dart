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
}
