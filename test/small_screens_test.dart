import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/app.dart';
import 'package:gastadoor/core/supabase/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

const user = User(
  id: 'u',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'someone.with.a.long.email.address@example.com',
  createdAt: '2026-10-21T08:00:00Z',
);

/// Screen sizes to check: iPhone SE (smallest), iPhone 8, iPhone 15.
const phones = [(320.0, 568.0), (375.0, 667.0), (390.0, 844.0)];

/// Normal text, and the iPhone's larger accessibility text sizes.
const textSizes = [1.0, 1.3, 2.0];

void main() {
  for (final (width, height) in phones) {
    for (final textSize in textSizes) {
      testWidgets(
        'everything fits on a ${width.toInt()}x${height.toInt()} screen '
        'with text x$textSize',
        (tester) async {
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = textSize;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentUserProvider.overrideWith((ref) => Stream.value(user)),
              ],
              child: const GastaDoorApp(),
            ),
          );
          // Placeholders pulse forever, so wait a moment instead of "settle".
          await tester.pump(const Duration(seconds: 1));

          // Visit every tab and open the + form. Any layout overflow fails
          // the test (Flutter reports it as an exception).
          for (final tab in ['Accounts', 'History', 'Home']) {
            await tester.tap(find.bySemanticsLabel(tab));
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull, reason: tab);
          }
          await tester.tap(find.byTooltip('Add expense'));
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull, reason: '+ form');
        },
      );
    }
  }
}
