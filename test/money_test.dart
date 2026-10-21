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

    test('rejects invalid input', () {
      expect(Money.parseToCents(''), isNull);
      expect(Money.parseToCents('1.234'), isNull);
      expect(Money.parseToCents('abc'), isNull);
    });
  });
}
