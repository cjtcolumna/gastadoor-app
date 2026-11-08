import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/core/utils/dates.dart';
import 'package:gastadoor/core/widgets/amount_hero_field.dart';
import 'package:gastadoor/core/widgets/pill_height.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/accounts/presentation/account_picker_cards.dart';
import 'package:gastadoor/features/budgets/data/budgets_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget_progress.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/categories/presentation/category_pill.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/transactions/data/transaction_actions.dart';
import 'package:gastadoor/features/transactions/data/transactions_repository.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:gastadoor/features/transactions/domain/transaction_draft.dart';
import 'package:gastadoor/features/transactions/presentation/transaction_form_sheet.dart';

const cashAccount = Account(
  id: 'cash',
  userId: 'u',
  name: 'Cash',
  type: AccountType.cash,
);
const gcashAccount = Account(
  id: 'gcash',
  userId: 'u',
  name: 'GCash',
  type: AccountType.eWallet,
);

class FakeAccountsNotifier extends AccountsNotifier {
  FakeAccountsNotifier([this.accounts = const [cashAccount, gcashAccount]]);

  final List<Account> accounts;

  @override
  Future<List<Account>> build() async => accounts;
}

/// Records what the form asked to save instead of calling Supabase.
class FakeActions implements TransactionActions {
  final added = <TransactionDraft>[];
  final updated = <(String, TransactionDraft)>[];
  final deleted = <String>[];

  @override
  Future<void> add(TransactionDraft draft) async => added.add(draft);

  @override
  Future<void> update(String id, TransactionDraft draft) async =>
      updated.add((id, draft));

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  void refreshScreens() {}
}

const categories = [
  Category(
    id: 'food',
    userId: 'u',
    name: 'Food',
    kind: TransactionKind.expense,
    icon: 'restaurant',
    color: 'orange',
  ),
  Category(
    id: 'salary',
    userId: 'u',
    name: 'Salary',
    kind: TransactionKind.income,
    icon: 'work',
    color: 'green',
  ),
];

void main() {
  late FakeActions actions;

  /// Shows a button that opens the sheet, like the real "+" button does.
  Future<void> openSheet(
    WidgetTester tester, {
    Transaction? existing,
    List<Account> accounts = const [cashAccount, gcashAccount],
    String? lastUsedAccountId,
    String? lastCategoryId,
    List<BudgetProgress> budgets = const [],
    List<Category> categoryList = categories,
    Map<String, int> balances = const {
      'cash': 150000, // ₱1,500.00
      'gcash': -2505, // -₱25.05
      'g': 500000,
      't': 120000,
    },
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    actions = FakeActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(() => FakeAccountsNotifier(accounts)),
          categoriesProvider.overrideWith((ref) async => categoryList),
          lastUsedAccountIdProvider.overrideWith(
            (ref) async => lastUsedAccountId,
          ),
          lastCategoryIdProvider.overrideWith(
            (ref, kind) async =>
                kind == TransactionKind.expense ? lastCategoryId : null,
          ),
          accountBalancesProvider.overrideWith((ref) async => balances),
          budgetProgressProvider.overrideWith((ref) async => budgets),
          archivedAccountsProvider.overrideWith(
            (ref) async => const [
              Account(
                id: 'old',
                userId: 'u',
                name: 'Old Wallet',
                type: AccountType.eWallet,
                archived: true,
              ),
            ],
          ),
          transactionActionsProvider.overrideWithValue(actions),
        ],
        child: MaterialApp(
          theme: AppTheme.light(), // the real app theme
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTransactionFormSheet(context, existing: existing),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// The pill for an account in an account picker (0 = the first one; a
  /// transfer has From, then To). Not the heading with the same name.
  Finder inPicker(String text, {int picker = 0}) => find.descendant(
    of: find.byType(AccountPickerCards).at(picker),
    matching: find.widgetWithText(ChoiceChip, text),
  );

  Future<void> pickAccount(
    WidgetTester tester,
    String name, {
    int picker = 0,
  }) => tapVisible(tester, inPicker(name, picker: picker));

  Finder amountField() => find.byType(TextFormField).first;
  Finder save() => find.widgetWithText(FilledButton, 'Save');

  testWidgets('needs an amount above zero', (tester) async {
    await openSheet(tester);

    await tapVisible(tester, save());
    expect(find.text('Enter an amount'), findsOneWidget);

    await tester.enterText(amountField(), '0');
    await tapVisible(tester, save());
    expect(find.text('Enter an amount above zero'), findsOneWidget);
    expect(actions.added, isEmpty);
  });

  testWidgets('saves an expense with category, account, and note', (
    tester,
  ) async {
    await openSheet(tester);
    expect(find.text('New expense'), findsOneWidget);

    await tester.enterText(amountField(), '189.50');
    await tapVisible(tester, find.text('Food'));
    await pickAccount(tester, 'GCash');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What was this for?'),
      'Jollibee',
    );
    await tapVisible(tester, save());

    final draft = actions.added.single;
    expect(draft.kind, TransactionKind.expense);
    expect(draft.amountCents, 18950);
    expect(draft.categoryId, 'food');
    expect(draft.accountId, 'gcash');
    expect(draft.occurredOn, dateOnly(DateTime.now()));
    expect(draft.note, 'Jollibee');
    expect(find.text('New expense'), findsNothing); // sheet closed
  });

  testWidgets('uses the first account when none is picked', (tester) async {
    await openSheet(tester);
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());

    expect(actions.added.single.accountId, 'cash');
    expect(actions.added.single.categoryId, isNull);
  });

  testWidgets('switching to Income shows income categories', (tester) async {
    await openSheet(tester);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);

    await tapVisible(tester, find.text('Income'));
    expect(find.text('New income'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsNothing);
  });

  final existing = Transaction(
    id: 'txn-1',
    userId: 'u',
    accountId: 'gcash',
    categoryId: 'food',
    kind: TransactionKind.expense,
    amountCents: 24500,
    occurredOn: DateTime(2026, 10, 1),
    note: 'Grab',
  );

  testWidgets('edits an existing expense', (tester) async {
    await openSheet(tester, existing: existing);
    expect(find.text('Edit expense'), findsOneWidget);
    expect(find.text('245.00'), findsOneWidget);
    expect(find.text('October 1, 2026'), findsOneWidget);

    await tester.enterText(amountField(), '250');
    await tapVisible(tester, save());

    final (id, draft) = actions.updated.single;
    expect(id, 'txn-1');
    expect(draft.amountCents, 25000);
    expect(draft.accountId, 'gcash');
  });

  testWidgets('editing shows the archived account it came from', (
    tester,
  ) async {
    final fromOldWallet = existing.copyWith(accountId: 'old');
    await openSheet(tester, existing: fromOldWallet);

    expect(find.text('Old Wallet (archived)'), findsOneWidget);
    // Saving keeps it on the archived account.
    await tapVisible(tester, save());
    expect(actions.updated.single.$2.accountId, 'old');
  });

  testWidgets('deletes only after confirming', (tester) async {
    await openSheet(tester, existing: existing);

    await tapVisible(tester, find.text('Delete expense'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(actions.deleted, isEmpty);

    await tapVisible(tester, find.text('Delete expense'));
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(actions.deleted, ['txn-1']);
  });

  testWidgets('selected switch and chips keep their rounded icons', (
    tester,
  ) async {
    await openSheet(tester);
    await tapVisible(tester, find.text('Income'));
    await tapVisible(tester, find.text('Salary'));
    await pickAccount(tester, 'GCash');

    final kindSwitch = tester.widget<SegmentedButton<TransactionKind>>(
      find.byType(SegmentedButton<TransactionKind>),
    );
    expect(kindSwitch.showSelectedIcon, isFalse);
    // The Income arrow, Salary icon, and GCash's own icon are all shown.
    expect(find.byIcon(Icons.south_west_rounded), findsOneWidget);
    expect(find.byIcon(Icons.work_rounded), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/banks/gcash.png')),
      findsOneWidget,
    );
  });

  testWidgets('a transfer moves money from one account to another', (
    tester,
  ) async {
    await openSheet(tester);
    await tapVisible(tester, find.text('Transfer'));

    expect(find.text('New transfer'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Category'), findsNothing); // transfers have none

    await tester.enterText(amountField(), '1,000');
    await tapVisible(tester, save());

    final draft = actions.added.single;
    expect(draft.kind, TransactionKind.transfer);
    expect(draft.amountCents, 100000);
    expect(draft.accountId, 'cash'); // From: first account
    expect(draft.toAccountId, 'gcash'); // To: the other one
    expect(draft.toRow()['category_id'], isNull);
  });

  testWidgets('the To list never offers the From account', (tester) async {
    await openSheet(tester);
    await tapVisible(tester, find.text('Transfer'));
    // Pick GCash as From: To must switch to Cash automatically.
    await pickAccount(tester, 'GCash');
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());

    final draft = actions.added.single;
    expect(draft.accountId, 'gcash');
    expect(draft.toAccountId, 'cash');
  });

  testWidgets('a transfer needs two accounts', (tester) async {
    await openSheet(tester, accounts: const [cashAccount]);
    await tapVisible(tester, find.text('Transfer'));
    expect(
      find.text('Add a second account to make transfers.'),
      findsOneWidget,
    );

    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());
    expect(
      find.textContaining('A transfer needs two accounts'),
      findsOneWidget,
    );
    expect(actions.added, isEmpty);
  });

  testWidgets('editing a transfer keeps From and To', (tester) async {
    final transfer = Transaction(
      id: 'tr-1',
      userId: 'u',
      accountId: 'gcash',
      toAccountId: 'cash',
      kind: TransactionKind.transfer,
      amountCents: 20000,
      occurredOn: DateTime(2026, 10, 2),
    );
    await openSheet(tester, existing: transfer);
    expect(find.text('Edit transfer'), findsOneWidget);

    await tapVisible(tester, save());
    final (id, draft) = actions.updated.single;
    expect(id, 'tr-1');
    expect(draft.accountId, 'gcash');
    expect(draft.toAccountId, 'cash');
  });

  testWidgets('"+ New" adds a category without leaving the form', (
    tester,
  ) async {
    await openSheet(tester);
    await tapVisible(tester, find.byTooltip('New category'));
    expect(find.text('New expense category'), findsOneWidget);
  });

  testWidgets('"+ New" on the Income tab makes an income category', (
    tester,
  ) async {
    await openSheet(tester);
    await tapVisible(tester, find.text('Income'));
    await tapVisible(tester, find.byTooltip('New category'));
    expect(find.text('New income category'), findsOneWidget);
  });

  const gotyme = Account(
    id: 'g',
    userId: 'u',
    name: 'GoTyme',
    type: AccountType.bank,
  );
  const travel = Account(
    id: 't',
    userId: 'u',
    name: 'Travel',
    type: AccountType.bank,
    parentId: 'g',
  );

  testWidgets('an expense can come from a sub-account (pocket)', (
    tester,
  ) async {
    // Travel was made after Cash, but sits in GoTyme's card.
    await openSheet(tester, accounts: [gotyme, cashAccount, travel]);
    await tester.enterText(amountField(), '2500');

    // Each group first: its account, then its sub-accounts (named just
    // "Travel"). Accounts without sub-accounts (Cash) come last.
    final labels = tester
        .widgetList<ChoiceChip>(
          find.descendant(
            of: find.byType(AccountPickerCards),
            matching: find.byType(ChoiceChip),
          ),
        )
        // Each label is the name with the balance under it: take the name.
        .map((chip) => ((chip.label as Column).children.first as Text).data);
    expect(labels, ['GoTyme', 'Travel', 'Cash']);

    await pickAccount(tester, 'Travel');
    await tapVisible(tester, save());
    expect(actions.added.single.accountId, 't');
  });

  testWidgets('groups have a heading and a line, not a box', (tester) async {
    await openSheet(tester, accounts: [gotyme, cashAccount, travel]);
    final picker = find.byType(AccountPickerCards);

    // "Other accounts" for Cash, and "GoTyme" for GoTyme and its Travel.
    expect(
      find.descendant(of: picker, matching: find.text('Other accounts')),
      findsOneWidget,
    );
    // The group comes first, "Other accounts" on the last row.
    expect(
      tester.getTopLeft(find.text('GoTyme').first).dy,
      lessThan(tester.getTopLeft(find.text('Other accounts')).dy),
    );
    // "GoTyme" is both the heading and the main pill.
    expect(
      find.descendant(of: picker, matching: find.text('GoTyme')),
      findsNWidgets(2),
    );
    // Each heading has two lines: one before the name, one after it.
    expect(
      find.descendant(of: picker, matching: find.byType(Divider)),
      findsNWidgets(4),
    );
    // No boxes around the groups: nothing with a border on all four sides
    // (the divider lines only have a bottom edge).
    expect(
      find.descendant(
        of: picker,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).border?.top != BorderSide.none &&
              (w.decoration! as BoxDecoration).border?.top != null,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('the line after a heading runs to the end of the picker', (
    tester,
  ) async {
    await openSheet(tester, accounts: [gotyme, cashAccount, travel]);
    final pickerRight = tester.getRect(find.byType(AccountPickerCards)).right;
    final lines = find.descendant(
      of: find.byType(AccountPickerCards),
      matching: find.byType(Divider),
    );
    // Dividers come in pairs per heading: short one first, long one last.
    final first = tester.getRect(lines.at(0));
    final name = tester.getRect(find.text('GoTyme').first);
    final last = tester.getRect(lines.at(1));
    expect(first.width, lessThan(20));
    expect(first.right, lessThan(name.left)); // short line, then the name
    expect(last.left, greaterThanOrEqualTo(name.right));
    expect(last.right, closeTo(pickerRight, 0.5));
  });

  testWidgets('sub-account pills have an icon too', (tester) async {
    await openSheet(tester, accounts: [gotyme, cashAccount, travel]);
    final travelPill = find.widgetWithText(ChoiceChip, 'Travel');
    final chip = tester.widget<ChoiceChip>(travelPill);
    expect(chip.avatar, isNotNull);
    expect(
      find.descendant(of: travelPill, matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets('no heading when no account has sub-accounts', (tester) async {
    await openSheet(tester);
    final picker = find.byType(AccountPickerCards);
    expect(
      find.descendant(of: picker, matching: find.text('Other accounts')),
      findsNothing,
    );
    expect(
      find.descendant(of: picker, matching: find.byType(Divider)),
      findsNothing,
    );
  });

  testWidgets('pills keep a gap when they wrap onto the next line', (
    tester,
  ) async {
    final many = [
      for (var i = 1; i <= 9; i++)
        Account(
          id: 'a$i',
          userId: 'u',
          name: 'Account number $i',
          type: AccountType.bank,
        ),
    ];
    await openSheet(tester, accounts: many, balances: const {});

    final rects = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((chip) => tester.getRect(find.byWidget(chip)))
        .toList();
    final rowTops = {for (final r in rects) r.top.round()}.toList()..sort();
    expect(rowTops.length, greaterThan(1)); // it really wrapped
    for (var i = 1; i < rowTops.length; i++) {
      final above = rects.where((r) => r.top.round() == rowTops[i - 1]);
      final bottom = above.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
      expect(rowTops[i] - bottom, greaterThanOrEqualTo(8));
    }
  });

  testWidgets('each pill shows its balance in small text under the name', (
    tester,
  ) async {
    await openSheet(tester, accounts: [gotyme, cashAccount, travel]);
    expect(find.text('₱1,500.00'), findsOneWidget); // Cash
    expect(find.text('₱5,000.00'), findsOneWidget); // GoTyme
    expect(find.text('₱1,200.00'), findsOneWidget); // Travel

    final name = tester.widget<Text>(find.text('Cash'));
    final balance = tester.widget<Text>(find.text('₱1,500.00'));
    expect(
      balance.style!.fontSize!,
      lessThan(
        name.style?.fontSize ??
            DefaultTextStyle.of(tester.element(find.text('Cash')))
                .style
                .fontSize!,
      ),
    );
  });

  testWidgets('a negative balance is shown in the expense color', (
    tester,
  ) async {
    await openSheet(tester); // GCash is at -₱25.05
    final negative = tester.widget<Text>(find.text('-₱25.05'));
    expect(negative.style!.color, AppColors.light.expense);
  });

  testWidgets('no balances are shown until they have loaded', (tester) async {
    await openSheet(tester, balances: const {});
    // Unknown balance = nothing under the names, but the pills still work.
    expect(
      find.descendant(
        of: find.byType(AccountPickerCards),
        matching: find.textContaining('₱'),
      ),
      findsNothing,
    );
    await pickAccount(tester, 'GCash');
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());
    expect(actions.added.single.accountId, 'gcash');
  });

  testWidgets('a selected account pill is a light fill of its own color', (
    tester,
  ) async {
    await openSheet(tester, accounts: [cashAccount, gotyme, travel]);

    ChoiceChip chip(String label) => tester.widget<ChoiceChip>(
      find.descendant(
        of: find.byType(AccountPickerCards),
        matching: find.widgetWithText(ChoiceChip, label),
      ),
    );
    double hue(Color? c) => HSLColor.fromColor(c!).hue;

    // Cash has no bank: the app green, light, with a green border.
    final green = AppTheme.light().colorScheme.primary;
    expect(chip('Cash').selectedColor, lightFill(green));
    expect(chip('Cash').side, BorderSide(color: green));
    expect(
      HSLColor.fromColor(chip('Cash').selectedColor!).lightness,
      greaterThan(0.8),
    );

    // GoTyme: its own teal, not green.
    await pickAccount(tester, 'GoTyme');
    expect(chip('Cash').side, isNull); // no longer selected
    final teal = chip('GoTyme').selectedColor;
    expect(hue(teal), closeTo(hue(const Color(0xFF05E6FA)), 1));
    expect(chip('GoTyme').side, const BorderSide(color: Color(0xFF05E6FA)));

    // Its sub-account Travel uses the same teal.
    await pickAccount(tester, 'Travel');
    expect(chip('Travel').selectedColor, teal);
  });

  testWidgets('the picked category gets a thin border in its color', (
    tester,
  ) async {
    await openSheet(tester);
    BorderSide border() {
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(CategoryPill),
              matching: find.byType(Material),
            )
            .first,
      );
      return (material.shape! as RoundedRectangleBorder).side;
    }

    final unselected = border();
    await tapVisible(tester, find.text('Food'));
    expect(border().color, isNot(unselected.color));
    expect(border().color.a, 1);
  });

  testWidgets('the amount is red for expense, green for income, blue for '
      'transfer', (tester) async {
    await openSheet(tester);
    final colors = tester.element(find.byType(AmountHeroField)).appColors;
    Color amountColor() =>
        tester.widget<AmountHeroField>(find.byType(AmountHeroField)).color;

    expect(amountColor(), colors.expense);
    await tapVisible(tester, find.text('Income'));
    expect(amountColor(), colors.income);
    await tapVisible(tester, find.text('Transfer'));
    expect(amountColor(), colors.transfer);
  });

  testWidgets('starts on the category used last time', (tester) async {
    await openSheet(tester, lastCategoryId: 'food');
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());
    expect(actions.added.single.categoryId, 'food');
  });

  testWidgets('tapping the remembered category clears it', (tester) async {
    await openSheet(tester, lastCategoryId: 'food');
    await tapVisible(tester, find.text('Food'));
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());
    expect(actions.added.single.categoryId, isNull);
  });

  testWidgets('income does not start on an expense category', (tester) async {
    // Food is an expense category: it must not carry over to Income.
    await openSheet(tester, lastCategoryId: 'food');
    await tapVisible(tester, find.text('Income'));
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());
    expect(actions.added.single.categoryId, isNull);
  });

  testWidgets('editing never fills in a category the transaction lacked', (
    tester,
  ) async {
    await openSheet(
      tester,
      lastCategoryId: 'food',
      existing: existing.copyWith(categoryId: null),
    );
    await tapVisible(tester, save());
    expect(actions.updated.single.$2.categoryId, isNull);
  });

  testWidgets('the date shows the whole date', (tester) async {
    await openSheet(tester);
    expect(find.text(fullDate(DateTime.now())), findsOneWidget);
    expect(find.textContaining('Today, '), findsOneWidget);
  });

  testWidgets('starts on the account used last time', (tester) async {
    await openSheet(tester, lastUsedAccountId: 'gcash');
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());

    expect(actions.added.single.accountId, 'gcash');
  });

  testWidgets('falls back to the first account if the last one is gone', (
    tester,
  ) async {
    await openSheet(tester, lastUsedAccountId: 'deleted-account');
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());

    expect(actions.added.single.accountId, 'cash');
  });

  testWidgets('a transfer greys out the From account in the To list', (
    tester,
  ) async {
    await openSheet(tester, lastUsedAccountId: 'gcash');
    await tapVisible(tester, find.text('Transfer'));

    // From = GCash (last used), so GCash is disabled under "To".
    ChoiceChip gcashIn(int picker) => tester.widget<ChoiceChip>(
      find.descendant(
        of: find.byType(AccountPickerCards).at(picker),
        matching: find.widgetWithText(ChoiceChip, 'GCash'),
      ),
    );
    expect(gcashIn(0).onSelected, isNotNull); // From
    expect(gcashIn(1).onSelected, isNull); // To
  });

  BudgetProgress foodBudget({required int spent, required int limit}) =>
      BudgetProgress(
        category: categories.first.copyWith(budgetCents: limit),
        limitCents: limit,
        spentCents: spent,
      );

  testWidgets('the peso sign is always shown, even with no amount', (
    tester,
  ) async {
    await openSheet(tester);
    expect(find.text('₱'), findsOneWidget);
    // Still there after tapping away from the field, and once typed in.
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('₱'), findsOneWidget);
    await tester.enterText(amountField(), '12');
    await tester.pumpAndSettle();
    expect(find.text('₱'), findsOneWidget);
  });

  testWidgets('notes come right after the amount, under a Notes header', (
    tester,
  ) async {
    await openSheet(tester);
    double top(Finder f) => tester.getTopLeft(f).dy;
    final notes = find.widgetWithText(TextFormField, 'What was this for?');

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Note (optional)'), findsNothing);
    expect(
      top(find.byType(AmountHeroField)),
      lessThan(top(find.text('Notes'))),
    );
    expect(top(find.text('Notes')), lessThan(top(notes)));
    expect(top(notes), lessThan(top(find.text('Category'))));
    expect(top(find.text('Category')), lessThan(top(find.text('Date'))));
  });

  testWidgets('the notes hint changes with the type', (tester) async {
    await openSheet(tester);
    expect(find.text('What was this for?'), findsOneWidget);
    await tapVisible(tester, find.text('Income'));
    expect(find.text('Where did this come from?'), findsOneWidget);
    await tapVisible(tester, find.text('Transfer'));
    expect(find.text('Why are you moving this?'), findsOneWidget);
    // No "0/500" counter under the field.
    expect(find.text('0/500'), findsNothing);
  });

  testWidgets('a category with a budget shows spent/limit under its name', (
    tester,
  ) async {
    await openSheet(tester, budgets: [foodBudget(spent: 0, limit: 85000)]);
    expect(find.text('₱0/₱850'), findsOneWidget);

    final name = tester.widget<Text>(find.text('Food'));
    final numbers = tester.widget<Text>(find.text('₱0/₱850'));
    expect(numbers.style!.fontSize, 9);
    expect(numbers.style!.fontSize!, lessThan(name.style!.fontSize!));
  });

  testWidgets('budget numbers use the short format', (tester) async {
    await openSheet(
      tester,
      budgets: [foodBudget(spent: 1050000, limit: 1500000)],
    );
    expect(find.text('₱10.5k/₱15k'), findsOneWidget);
  });

  testWidgets('a category without a budget shows no numbers or bar', (
    tester,
  ) async {
    await openSheet(tester);
    expect(find.textContaining('/₱'), findsNothing);
    final ring = tester.widget<BudgetRing>(find.byType(BudgetRing));
    expect(ring.progress, isNull); // an icon with no ring
  });

  testWidgets('income categories never show a budget', (tester) async {
    await openSheet(tester, budgets: [foodBudget(spent: 0, limit: 85000)]);
    await tapVisible(tester, find.text('Income'));
    expect(find.textContaining('/₱'), findsNothing);
    expect(tester.widget<BudgetRing>(find.byType(BudgetRing)).progress, isNull);
  });

  BudgetRing ring(WidgetTester tester) =>
      tester.widget<BudgetRing>(find.byType(BudgetRing).first);
  final statusColors = AppTheme.light().extension<AppColors>()!;

  testWidgets('the icon has a donut that fills with the budget used', (
    tester,
  ) async {
    await openSheet(tester, budgets: [foodBudget(spent: 20000, limit: 100000)]);
    expect(ring(tester).progress, closeTo(0.2, 0.001));
    expect(ring(tester).color, statusColors.income); // under 75%: green
    // The ring is drawn around the category icon.
    expect(
      find.descendant(
        of: find.byType(BudgetRing),
        matching: find.byIcon(Icons.restaurant_rounded),
      ),
      findsOneWidget,
    );
    // And there is no bar any more.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('the donut turns amber from 75% used', (tester) async {
    await openSheet(tester, budgets: [foodBudget(spent: 80000, limit: 100000)]);
    expect(ring(tester).color, statusColors.warning);
  });

  testWidgets('the donut is full and red once over', (tester) async {
    await openSheet(
      tester,
      budgets: [foodBudget(spent: 150000, limit: 100000)],
    );
    expect(ring(tester).progress, 1.0); // full, and stays full
    expect(ring(tester).color, statusColors.expense);
  });

  testWidgets('category pills share one height, and widths fit the content', (
    tester,
  ) async {
    const more = [
      Category(
        id: 'food',
        userId: 'u',
        name: 'Food',
        kind: TransactionKind.expense,
        icon: 'restaurant',
        color: 'orange',
      ),
      Category(
        id: 'fun',
        userId: 'u',
        name: 'Fun',
        kind: TransactionKind.expense,
        icon: 'pets',
        color: 'pink',
      ),
      Category(
        id: 'entertainment',
        userId: 'u',
        name: 'Entertainment and fun things for the weekend and holidays',
        kind: TransactionKind.expense,
        icon: 'celebration',
        color: 'purple',
      ),
    ];
    // Only Food has a budget; heights must still match.
    await openSheet(
      tester,
      categoryList: more,
      budgets: [foodBudget(spent: 1050000, limit: 1500000)],
    );

    final sizes = [
      for (final w in tester.widgetList(find.byType(CategoryPill)))
        tester.getSize(find.byWidget(w)),
    ];
    // Same height for all, and it is the shared pill height.
    expect({for (final s in sizes) s.height}, {pillHeight});
    // Widths are not forced to match: "Fun" (no budget) is narrower than
    // "Food" (with budget text), which is narrower than the long name.
    expect(sizes[1].width, lessThan(sizes[0].width));
    expect(sizes[0].width, lessThan(sizes[2].width));
    // A very long name is cut to fit the row, never wider than it.
    final rowWidth = tester.getSize(find.byType(Form)).width;
    expect(sizes[2].width, lessThanOrEqualTo(rowWidth));
  });

  testWidgets('category pills are the same height as account pills', (
    tester,
  ) async {
    await openSheet(
      tester,
      budgets: [foodBudget(spent: 0, limit: 85000)],
      balances: const {},
    );
    final category = tester.getSize(find.byType(CategoryPill).first).height;
    final account = tester
        .getSize(
          find
              .descendant(
                of: find.byType(AccountPickerCards),
                matching: find.byType(ChoiceChip),
              )
              .first,
        )
        .height;
    expect(category, pillHeight);
    // Even with no balance line under the name (balances not loaded).
    expect(account, pillHeight);
  });

  testWidgets('an account pill is the same height with or without a balance', (
    tester,
  ) async {
    await openSheet(tester);
    final withBalance = tester
        .getSize(
          find
              .descendant(
                of: find.byType(AccountPickerCards),
                matching: find.byType(ChoiceChip),
              )
              .first,
        )
        .height;
    expect(withBalance, pillHeight);
  });

  testWidgets('"+ New" is a pill after the categories, same height', (
    tester,
  ) async {
    await openSheet(tester);
    final pill = find.byType(NewCategoryPill);
    expect(pill, findsOneWidget);
    expect(
      find.descendant(of: pill, matching: find.text('New')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pill, matching: find.byIcon(Icons.add_rounded)),
      findsOneWidget,
    );
    // Same height as a category pill, and right after it on the same row.
    final category = tester.getRect(find.byType(CategoryPill).last);
    final add = tester.getRect(pill);
    expect(add.height, category.height);
    expect(add.height, pillHeight);
    expect(add.top, category.top);
    expect(add.left, greaterThan(category.right));
    // The old last-row button is gone.
    expect(find.widgetWithText(TextButton, 'New category'), findsNothing);
    // Tapping it opens the new-category form.
    await tapVisible(tester, pill);
    expect(find.text('New expense category'), findsOneWidget);
  });

  testWidgets('a pill with a budget can still be picked', (tester) async {
    await openSheet(tester, budgets: [foodBudget(spent: 0, limit: 85000)]);
    await tapVisible(tester, find.text('Food'));
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());
    expect(actions.added.single.categoryId, 'food');
  });

  testWidgets('the Save button is on screen without scrolling', (tester) async {
    await openSheet(tester);
    expect(tester.getBottomLeft(save()).dy, lessThanOrEqualTo(844));
    expect(find.byType(AmountHeroField), findsOneWidget);
  });
}
