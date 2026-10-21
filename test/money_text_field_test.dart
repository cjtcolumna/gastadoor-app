import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/widgets/money_text_field.dart';

/// Pretends the box held [before] and the user typed so it became [after].
/// Returns what the box actually shows afterwards.
String type(String before, String after, {bool allowNegative = false}) {
  return moneyInputFormatter(allowNegative: allowNegative)
      .formatEditUpdate(
        TextEditingValue(text: before),
        TextEditingValue(text: after),
      )
      .text;
}

void main() {
  group('moneyInputFormatter', () {
    test('allows numbers, commas and up to 2 decimals', () {
      expect(type('', '1'), '1');
      expect(type('1,23', '1,234'), '1,234');
      expect(type('12.5', '12.50'), '12.50');
    });

    test('blocks letters, a second dot, and a third decimal', () {
      expect(type('12', '12a'), '12');
      expect(type('1.5', '1.5.'), '1.5');
      expect(type('1.50', '1.505'), '1.50');
    });

    test('allows a minus sign only when asked', () {
      expect(type('', '-'), '');
      expect(type('', '-', allowNegative: true), '-');
      expect(type('-5', '-50', allowNegative: true), '-50');
    });
  });

  group('validateMoney', () {
    test('required amounts must be filled in', () {
      expect(validateMoney(''), 'Enter an amount');
      expect(validateMoney('', required: false), isNull);
    });

    test('rejects text that is not a full amount', () {
      expect(validateMoney('-'), 'Enter a valid amount');
      expect(validateMoney('12.5'), isNull);
    });
  });
}
