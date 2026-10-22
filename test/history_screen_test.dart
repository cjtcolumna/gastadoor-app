import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/transactions/data/transactions_repository.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
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
          'account': {'name': 'GCash'},
          'categories': {'name': 'Food'},
        }),
    ],
  );
}

/// The History list's scroll area (the chip row scrolls too, sideways).
final listScrollable = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

/// Every filter + page the screen asked for, in order.
final asked = <HistoryQuery>[];

/// Shows History with [total] fake expenses. When any filter or search is
/// on, the fake database returns [filteredTotal] matches instead.
Future<void> pumpHistory(
  WidgetTester tester,
  int total, {
  int? filteredTotal,
}) async {
  asked.clear();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        historyPageProvider.overrideWith((ref, query) async {
          asked.add(query);
          final (filter, page) = query;
          final count = filter.isEmpty ? total : (filteredTotal ?? total);
          return fakePage(page, count);
        }),
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
    expect(find.text('GCash · Expense #1'), findsOneWidget);
    // Once on the row, once as the day's total in the date header.
    expect(find.text('− ₱189.00'), findsNWidgets(2));
  });

  testWidgets('pages through 45 expenses, 20 at a time', (tester) async {
    await pumpHistory(tester, 45);
    // The page buttons are below the 20 rows, so scroll down to them.
    await tester.scrollUntilVisible(
      find.text('Next'),
      300,
      scrollable: listScrollable,
    );
    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(find.text('Showing 1–20 of 45'), findsOneWidget);

    await tapNext(tester);
    // A new page starts at the top, showing expense #21 first.
    expect(find.text('GCash · Expense #21'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Next'),
      300,
      scrollable: listScrollable,
    );
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.text('Showing 21–40 of 45'), findsOneWidget);

    await tapNext(tester);
    await tester.scrollUntilVisible(
      find.text('Next'),
      300,
      scrollable: listScrollable,
    );
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

  testWidgets('shows a transfer as From → To with no plus or minus', (
    tester,
  ) async {
    final transfer = TransactionListItem.fromRow({
      'id': 'tr',
      'user_id': 'u',
      'account_id': 'cash',
      'to_account_id': 'gcash',
      'kind': 'transfer',
      'amount_cents': 100000,
      'occurred_on': '2026-10-21',
      'account': {'name': 'Cash'},
      'to_account': {'name': 'GCash'},
      'categories': null,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyPageProvider.overrideWith(
            (ref, query) async =>
                TransactionPage(items: [transfer], page: 0, totalCount: 1),
          ),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Cash → GCash'), findsOneWidget);
    expect(find.text('₱1,000.00'), findsOneWidget);
    expect(find.textContaining('− ₱1,000.00'), findsNothing);
  });

  testWidgets('search waits for typing to pause, then searches notes', (
    tester,
  ) async {
    await pumpHistory(tester, 45, filteredTotal: 2);
    await tester.enterText(find.byType(TextField), 'Jollibee');
    await tester.pump(const Duration(milliseconds: 100));
    // Not yet: still waiting for typing to pause.
    expect(asked.last.$1.search, '');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final (filter, page) = asked.last;
    expect(filter.search, 'Jollibee');
    expect(page, 0);
    expect(find.text('Showing 1–2 of 2'), findsOneWidget);
  });

  testWidgets('the Type chip filters to one kind, and Clear resets', (
    tester,
  ) async {
    await pumpHistory(tester, 45, filteredTotal: 3);
    expect(find.text('Clear'), findsNothing);

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();

    expect(asked.last.$1.kind, TransactionKind.income);
    expect(find.text('Showing 1–3 of 3'), findsOneWidget);

    await tester.ensureVisible(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    // Back to everything. (It's shown from memory, so no new request.)
    expect(find.text('Clear'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Next'),
      300,
      scrollable: listScrollable,
    );
    expect(find.text('Showing 1–20 of 45'), findsOneWidget);
  });

  testWidgets('a new filter goes back to page 1', (tester) async {
    await pumpHistory(tester, 45);
    await tester.scrollUntilVisible(
      find.text('Next'),
      300,
      scrollable: listScrollable,
    );
    await tapNext(tester);
    expect(asked.last.$2, 1);

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses').last);
    await tester.pumpAndSettle();
    expect(asked.last.$2, 0);
  });

  testWidgets('no matches shows a way to clear the filters', (tester) async {
    await pumpHistory(tester, 45, filteredTotal: 0);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('No matches'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    // The search box is empty again and the full list is back.
    expect(find.textContaining('No matches'), findsNothing);
    final box = tester.widget<TextField>(find.byType(TextField));
    expect(box.controller!.text, '');
    expect(find.text('GCash · Expense #1'), findsOneWidget);
  });
}
