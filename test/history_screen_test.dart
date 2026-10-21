import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/transactions/data/transactions_repository.dart';
import 'package:gastadoor/features/transactions/domain/transaction_page.dart';
import 'package:gastadoor/features/transactions/presentation/history_screen.dart';

/// Pretends the database holds [total] expenses, numbered 1, 2, 3...
TransactionPage fakePage(int page, int total) {
  final (from, to) = TransactionPage.rowRange(page);
  final last = to < total ? to : total - 1;
  return TransactionPage(
    page: page,
    totalCount: total,
    items: [
      for (var i = from; i <= last; i++)
        TransactionListItem.fromRow({
          'id': '$i',
          'user_id': 'u',
          'account_id': 'a',
          'kind': 'expense',
          'amount_cents': 18900,
          'occurred_on': '2026-10-21',
          'note': 'Expense #${i + 1}',
          'accounts': {'name': 'GCash'},
          'categories': {'name': 'Food'},
        }),
    ],
  );
}

Future<void> pumpHistory(WidgetTester tester, int total) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        historyPageProvider.overrideWith(
          (ref, page) async => fakePage(page, total),
        ),
      ],
      child: const MaterialApp(home: HistoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the Next button fully into view, then taps it.
Future<void> tapNext(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows expense details', (tester) async {
    await pumpHistory(tester, 1);

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Oct 21 · GCash · Expense #1'), findsOneWidget);
    expect(find.text('− ₱189.00'), findsOneWidget);
  });

  testWidgets('pages through 45 expenses, 20 at a time', (tester) async {
    await pumpHistory(tester, 45);
    // The page buttons are below the 20 rows, so scroll down to them.
    await tester.scrollUntilVisible(find.text('Next'), 300);
    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(find.text('Showing 1–20 of 45'), findsOneWidget);

    await tapNext(tester);
    // A new page starts at the top, showing expense #21 first.
    expect(find.text('Oct 21 · GCash · Expense #21'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Next'), 300);
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.text('Showing 21–40 of 45'), findsOneWidget);

    await tapNext(tester);
    await tester.scrollUntilVisible(find.text('Next'), 300);
    expect(find.text('Showing 41–45 of 45'), findsOneWidget);
    // On the last page, Next is turned off.
    final next = tester.widget<TextButton>(
      find.ancestor(of: find.text('Next'), matching: find.byType(TextButton)),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('shows a friendly message when there is no history', (
    tester,
  ) async {
    await pumpHistory(tester, 0);
    expect(find.textContaining('No expenses yet'), findsOneWidget);
  });
}
