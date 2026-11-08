import 'package:flutter/material.dart';
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

  testWidgets('built-in icons from the theme are rounded too', (tester) async {
    final theme = AppTheme.light();
    expect(theme.chipTheme.showCheckmark, isFalse);
    final check = theme.segmentedButtonTheme.selectedIcon as Icon?;
    expect(check?.icon, Icons.check_rounded);

    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    final back = theme.actionIconTheme?.backButtonIconBuilder?.call(context);
    final close = theme.actionIconTheme?.closeButtonIconBuilder?.call(context);
    expect((back as Icon?)?.icon, Icons.arrow_back_rounded);
    expect((close as Icon?)?.icon, Icons.close_rounded);
  });

  group('segmented buttons', () {
    /// The fill behind the segment with this [label]. Null = no fill at all.
    Color? fillOf(WidgetTester tester, String label) {
      final segment = find.widgetWithText(TextButton, label);
      final material = find
          .descendant(of: segment, matching: find.byType(Material))
          .first;
      return tester.widget<Material>(material).color;
    }

    Future<void> pumpButton(WidgetTester tester, {required int selected}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('One')),
                ButtonSegment(value: 2, label: Text('Two')),
              ],
              selected: {selected},
              showSelectedIcon: false,
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('the chosen option is light gray, the others stay white', (
      tester,
    ) async {
      await pumpButton(tester, selected: 2);
      expect(fillOf(tester, 'One'), Colors.white);
      expect(fillOf(tester, 'Two'), AppTheme.selectedFill);

      // The gray follows the choice.
      await pumpButton(tester, selected: 1);
      expect(fillOf(tester, 'One'), AppTheme.selectedFill);
      expect(fillOf(tester, 'Two'), Colors.white);
    });
  });
}
