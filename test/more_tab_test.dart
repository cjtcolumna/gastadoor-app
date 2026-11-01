import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/router/app_shell.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/core/widgets/floating_nav_bar.dart';
import 'package:gastadoor/features/more/presentation/more_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('More screen', () {
    Future<void> pumpMore(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/more',
        routes: [
          GoRoute(
            path: '/more',
            builder: (_, _) => const MoreScreen(),
            routes: [
              GoRoute(
                path: 'budgets',
                builder: (_, _) => const Text('Budgets page'),
              ),
              GoRoute(
                path: 'categories',
                builder: (_, _) => const Text('Categories page'),
              ),
              GoRoute(
                path: 'loans',
                builder: (_, _) => const Text('Loans page'),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists budgets, categories and loans', (tester) async {
      await pumpMore(tester);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Loans'), findsOneWidget);
    });

    testWidgets('each row opens its page, with a way back', (tester) async {
      await pumpMore(tester);
      for (final (row, page) in [
        ('Budgets', 'Budgets page'),
        ('Categories', 'Categories page'),
        ('Loans', 'Loans page'),
      ]) {
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();
        expect(find.text(page), findsOneWidget);

        // Back to the menu.
        final context = tester.element(find.text(page));
        GoRouter.of(context).pop();
        await tester.pumpAndSettle();
        expect(find.text(row), findsOneWidget);
      }
    });
  });

  group('tab bar', () {
    test('has Home, Accounts, History and More', () {
      expect(appTabs.map((t) => t.label), [
        'Home',
        'Accounts',
        'History',
        'More',
      ]);
    });

    // Every label must fit with the round "+" button next to the bar, even
    // on a narrow phone. (Flutter fails a test on an overflow.)
    for (final width in [320.0, 360.0, 390.0]) {
      testWidgets('fits on a ${width.toInt()}px wide phone', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              bottomNavigationBar: FloatingNavBar(
                tabs: appTabs,
                currentIndex: 0,
                onTap: (_) {},
                onAdd: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final tab in appTabs) {
          expect(find.text(tab.label), findsOneWidget);
        }
      });
    }
  });
}
