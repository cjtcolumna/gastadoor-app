import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/app.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/core/widgets/skeleton.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/accounts/presentation/accounts_screen.dart';
import 'package:gastadoor/features/budgets/data/budgets_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget_progress.dart';

/// Accounts that never finish loading.
class LoadingForever extends AccountsNotifier {
  @override
  Future<List<Account>> build() => Completer<List<Account>>().future;
}

/// Accounts that fail the first time (no internet), then load.
class FailsOnce extends AccountsNotifier {
  static var attempts = 0;

  @override
  Future<List<Account>> build() async {
    attempts++;
    if (attempts == 1) {
      throw Exception('ClientException: XMLHttpRequest error.');
    }
    return const [
      Account(id: 'cash', userId: 'u', name: 'Cash', type: AccountType.cash),
    ];
  }
}

Future<void> pumpAccounts(WidgetTester tester, AccountsNotifier notifier) {
  return tester.pumpWidget(
    ProviderScope(
      // Riverpod retries failed loads by itself a few times. Turn that off
      // here so the test sees the error right away.
      retry: (retryCount, error) => null,
      overrides: [
        accountsProvider.overrideWith(() => notifier),
        archivedAccountsProvider.overrideWith((ref) async => const []),
        accountBalancesProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const AccountsScreen()),
    ),
  );
}

void main() {
  testWidgets('loading shows grey placeholders, not a spinner', (tester) async {
    await pumpAccounts(tester, LoadingForever());
    // The placeholders gently pulse forever, so wait a moment instead of
    // waiting for everything to "settle".
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SkeletonListCard), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an error explains itself and Try again reloads', (tester) async {
    FailsOnce.attempts = 0;
    await pumpAccounts(tester, FailsOnce());
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your accounts"), findsOneWidget);
    expect(
      find.text("You're offline. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(FailsOnce.attempts, 2);
    expect(find.text('Cash'), findsWidgets);
  });

  testWidgets('Home never invites you to add a budget before it knows', (
    tester,
  ) async {
    // A tall screen, so the Budgets section (below the spending chart)
    // is built without scrolling.
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Budgets still loading.
          budgetProgressProvider.overrideWith(
            (ref) => Completer<List<BudgetProgress>>().future,
          ),
        ],
        child: const GastaDoorApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Add a budget'), findsNothing);
    expect(find.byType(SkeletonListCard), findsWidgets);
  });

  testWidgets('placeholders stay still when animations are turned off', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: SkeletonListCard()),
      ),
    );
    // Settles right away because nothing is animating.
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SkeletonPulse),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });
}
