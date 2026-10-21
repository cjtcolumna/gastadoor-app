import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('accepts a normal email, even with spaces around it', () {
      expect(AuthValidators.email('jade@example.com'), isNull);
      expect(AuthValidators.email('  jade@example.com '), isNull);
    });

    test('rejects empty and malformed emails', () {
      expect(AuthValidators.email(''), 'Enter your email');
      expect(AuthValidators.email(null), 'Enter your email');
      expect(AuthValidators.email('jade'), 'Enter a valid email');
      expect(AuthValidators.email('jade@example'), 'Enter a valid email');
      expect(AuthValidators.email('ja de@example.com'), 'Enter a valid email');
    });
  });

  group('AuthValidators.password', () {
    test('accepts 6 or more characters', () {
      expect(AuthValidators.password('123456'), isNull);
    });

    test('rejects empty and short passwords', () {
      expect(AuthValidators.password(''), 'Enter your password');
      expect(AuthValidators.password('12345'), 'Use at least 6 characters');
    });
  });
}
