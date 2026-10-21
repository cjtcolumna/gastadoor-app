import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the theme uses Nunito for body text, titles, and buttons', () {
    final theme = AppTheme.light();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Nunito');
    expect(theme.textTheme.headlineMedium?.fontFamily, 'Nunito');
    final buttonText = theme.filledButtonTheme.style?.textStyle?.resolve({});
    expect(buttonText?.fontFamily, 'Nunito');
  });

  test('every Nunito weight is bundled with the app', () async {
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      final data = await rootBundle.load('assets/fonts/Nunito-$weight.ttf');
      expect(data.lengthInBytes, greaterThan(0), reason: weight);
    }
  });
}
