import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the theme uses Plus Jakarta Sans for body text, titles, and buttons',
    () {
      final theme = AppTheme.light();
      expect(theme.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans');
      expect(theme.textTheme.headlineMedium?.fontFamily, 'PlusJakartaSans');
      final buttonText = theme.filledButtonTheme.style?.textStyle?.resolve({});
      expect(buttonText?.fontFamily, 'PlusJakartaSans');
    },
  );

  test('every Plus Jakarta Sans weight is bundled with the app', () async {
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      final data = await rootBundle.load(
        'assets/fonts/PlusJakartaSans-$weight.ttf',
      );
      expect(data.lengthInBytes, greaterThan(0), reason: weight);
    }
  });
}
