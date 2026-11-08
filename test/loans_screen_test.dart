import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/core/utils/dates.dart';
import 'package:gastadoor/core/widgets/amount_hero_field.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/loans/data/loans_provider.dart';
import 'package:gastadoor/features/loans/domain/loan.dart';
import 'package:gastadoor/features/loans/domain/loan_summary.dart';
import 'package:gastadoor/features/loans/presentation/loan_detail_screen.dart';
import 'package:gastadoor/features/loans/presentation/loan_fields.dart';
import 'package:gastadoor/features/loans/presentation/loan_payment_sheet.dart';
import 'package:gastadoor/features/loans/presentation/loan_status_pill.dart';
import 'package:gastadoor/features/loans/presentation/loans_screen.dart';

/// What the screens asked to lend: person, cents, account id (null = none).
typedef Lent = (String, int, String?);

/// What the screens asked to record: loan id, cents, account id.
typedef Repaid = (String, int, String?);

/// Keeps loans in memory instead of Supabase.
class FakeLoansNotifier extends LoansNotifier {
  FakeLoansNotifier(this.start);

  final List<LoanWithPayments> start;
  final lent = <Lent>[];
  final repaid = <Repaid>[];

  @override
  Future<List<LoanWithPayments>> build() async => start;

  @override
  Future<void> add({
    required String person,
    required int amountCents,
    required DateTime lentOn,
    DateTime? dueOn,
    String? note,
    String? accountId,
  }) async => lent.add((person, amountCents, accountId));

  @override
  Future<void> addPayment({
    required String loanId,
    required int amountCents,
    required DateTime paidOn,
    String? note,
    String? accountId,
  }) async => repaid.add((loanId, amountCents, accountId));
}

class FakeAccounts extends AccountsNotifier {
  @override
  Future<List<Account>> build() async => const [
    Account(id: 'gotyme', userId: 'u', name: 'GoTyme', type: AccountType.bank),
    Account(id: 'cash', userId: 'u', name: 'Cash', type: AccountType.cash),
  ];
}

Loan loan(String id, String person, int cents, {String? accountId}) => Loan(
  id: id,
  userId: 'u',
  person: person,
  amountCents: cents,
  lentOn: DateTime(2026, 10, 1),
  accountId: accountId,
);

LoanPayment payment(String loanId, int cents, {String? accountId}) =>
    LoanPayment(
      id: 'p$loanId$cents',
      userId: 'u',
      loanId: loanId,
      amountCents: cents,
      paidOn: DateTime(2026, 10, 10),
      accountId: accountId,
    );

void main() {
  late FakeLoansNotifier fake;

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    List<LoanWithPayments> loans = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    fake = FakeLoansNotifier(loans);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loansProvider.overrideWith(() => fake),
          accountsProvider.overrideWith(FakeAccounts.new),
          accountBalancesProvider.overrideWith(
            (ref) async => {'gotyme': 500000, 'cash': 10000},
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The big amount box, and the name box of the Lend form.
  final amountField = find.descendant(
    of: find.byType(AmountHeroField),
    matching: find.byType(TextFormField),
  );
  final personField = find.byKey(const Key('loan-person'));

  /// Opens the Lend form from the Loans screen.
  Future<void> openLendForm(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Lend money'));
    await tester.pumpAndSettle();
  }

  /// Opens the account pills (they stay hidden behind one box until then).
  Future<void> openAccountRow(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('account-row')));
    await tester.pumpAndSettle();
  }

  /// Finds [text] inside the closed account box.
  Finder inAccountBox(String text) => find.descendant(
    of: find.byKey(const Key('account-row')),
    matching: find.text(text),
  );

  /// The form's big button. (The last one is the one on top.)
  Finder saveButton() => find.byType(FilledButton).last;

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
  }

  group('Loans screen', () {
    testWidgets('shows the total owed and groups loans by person', (
      tester,
    ) async {
      await pump(
        tester,
        const LoansScreen(),
        loans: [
          LoanWithPayments(loan('a', 'Mark', 1000000), [payment('a', 400000)]),
          LoanWithPayments(loan('b', 'Ana', 200000), [payment('b', 200000)]),
        ],
      );

      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text('From 1 person'), findsOneWidget);
      expect(find.text('Mark'), findsOneWidget);
      expect(find.text('₱6,000.00 owed'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('All paid back'), findsOneWidget);
    });

    testWidgets('every loan has a status pill, and partly paid ones a bar', (
      tester,
    ) async {
      await pump(
        tester,
        const LoansScreen(),
        loans: [
          LoanWithPayments(loan('a', 'Mark', 1000000), [payment('a', 400000)]),
          LoanWithPayments(loan('b', 'Ana', 200000), [payment('b', 200000)]),
          LoanWithPayments(loan('c', 'Zed', 50000), const []),
          LoanWithPayments(
            loan('d', 'Kim', 70000).copyWith(dueOn: DateTime(2020, 1, 1)),
            const [],
          ),
        ],
      );

      expect(find.text('Partly paid'), findsOneWidget);
      expect(find.text('Paid back'), findsOneWidget);
      expect(find.text('Not paid yet'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.textContaining('was due'), findsOneWidget);
      // Only the partly paid loan shows how much has come back.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // A letter circle for each person.
      expect(find.text('M'), findsOneWidget);
      expect(find.text('K'), findsOneWidget);
    });

    testWidgets('with no loans it invites you to lend money', (tester) async {
      await pump(tester, const LoansScreen());
      expect(find.textContaining('Lent money to a friend?'), findsOneWidget);
      expect(find.text('Nobody owes you right now'), findsOneWidget);
    });

    testWidgets('lending takes the money from the account you pick', (
      tester,
    ) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);

      await tester.enterText(personField, 'Mark');
      await tester.enterText(amountField, '10,000');
      // The first account is picked until you pick another.
      await tapSave(tester);

      expect(fake.lent, [('Mark', 1000000, 'gotyme')]);
    });

    testWidgets('the account is one box; its pills open when you tap it', (
      tester,
    ) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);

      // Closed: the account that will be used, and its balance.
      expect(find.widgetWithText(ChoiceChip, 'Cash'), findsNothing);
      expect(inAccountBox('GoTyme'), findsOneWidget);
      expect(inAccountBox('₱5,000.00'), findsOneWidget);

      await openAccountRow(tester);
      expect(find.widgetWithText(ChoiceChip, 'Cash'), findsOneWidget);
      // Tapping the box again closes them.
      await openAccountRow(tester);
      expect(find.widgetWithText(ChoiceChip, 'Cash'), findsNothing);
    });

    testWidgets('you can pick a different account', (tester) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);

      await tester.enterText(personField, 'Mark');
      await tester.enterText(amountField, '500');
      await openAccountRow(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
      await tester.pumpAndSettle();

      // Picking closes the pills and the box shows the new account.
      expect(find.widgetWithText(ChoiceChip, 'Cash'), findsNothing);
      expect(inAccountBox('Cash'), findsOneWidget);
      await tapSave(tester);

      expect(fake.lent, [('Mark', 50000, 'cash')]);
    });

    testWidgets('turning the switch off leaves every account alone', (
      tester,
    ) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);

      await tester.enterText(personField, 'Mark');
      await tester.enterText(amountField, '10000');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // The account box is hidden, and the reason is shown.
      expect(find.byKey(const Key('account-row')), findsNothing);
      expect(
        find.textContaining('before you started tracking'),
        findsOneWidget,
      );

      await tapSave(tester);
      expect(fake.lent, [('Mark', 1000000, null)]);
    });

    testWidgets('a name and an amount are required', (tester) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);

      await tapSave(tester);

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(fake.lent, isEmpty);
    });

    testWidgets('the button says what it will do', (tester) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);
      expect(find.widgetWithText(FilledButton, 'Lend'), findsOneWidget);

      await tester.enterText(amountField, '500');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Lend ₱500.00'), findsOneWidget);

      await tester.enterText(personField, 'Mark');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Lend ₱500.00 to Mark'),
        findsOneWidget,
      );
    });

    testWidgets('shows what the account balance will become', (tester) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);

      await tester.enterText(amountField, '1,000');
      await tester.pumpAndSettle();
      expect(find.text('GoTyme: ₱5,000.00 → ₱4,000.00'), findsOneWidget);
    });

    testWidgets('warns when you lend more than the account has', (
      tester,
    ) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);

      await tester.enterText(amountField, '10,000');
      await tester.pumpAndSettle();
      expect(
        find.textContaining("more than GoTyme has (₱5,000.00)"),
        findsOneWidget,
      );
      expect(find.textContaining('turn the switch off'), findsOneWidget);
    });

    testWidgets('people you lent to before are one tap away', (tester) async {
      await pump(
        tester,
        const LoansScreen(),
        loans: [
          LoanWithPayments(loan('a', 'Mark', 1000000), const []),
          LoanWithPayments(loan('b', 'Ana', 200000), const []),
        ],
      );
      await openLendForm(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Ana'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextFormField>(personField).controller!.text, 'Ana');
    });

    testWidgets('due date shortcuts set the date, and tapping again clears', (
      tester,
    ) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);
      expect(find.text('No due date'), findsOneWidget);

      final today = DateTime.now();
      final inAWeek = DateTime(today.year, today.month, today.day + 7);

      await tester.tap(find.widgetWithText(ChoiceChip, '1 week'));
      await tester.pumpAndSettle();
      expect(find.text(fullDate(inAWeek)), findsOneWidget);
      expect(find.text('No due date'), findsNothing);

      // The X next to the date clears it too.
      await tester.tap(find.byTooltip('Clear due date'));
      await tester.pumpAndSettle();
      expect(find.text('No due date'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, '1 week'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '1 week'));
      await tester.pumpAndSettle();
      expect(find.text('No due date'), findsOneWidget);
    });

    testWidgets('fits on a narrow 320px phone, with a due date set', (
      tester,
    ) async {
      await pump(tester, const LoansScreen());
      tester.view.physicalSize = const Size(320, 700);
      await openLendForm(tester);

      await tester.enterText(amountField, '10,000');
      await tester.enterText(personField, 'Alexandra Montgomery');
      final endOfMonth = find.widgetWithText(ChoiceChip, 'End of month');
      await tester.ensureVisible(endOfMonth);
      await tester.pumpAndSettle();
      await tester.tap(endOfMonth);
      await tester.pumpAndSettle();
      expect(find.text('No due date'), findsNothing);

      // Flutter fails a test on any overflow, so this must be empty.
      expect(tester.takeException(), isNull);
    });

    testWidgets('dates open the same calendar as Add transaction', (
      tester,
    ) async {
      await pump(tester, const LoansScreen());
      await openLendForm(tester);
      expect(find.text('No due date'), findsOneWidget);

      await tester.tap(find.byKey(const Key('date-due')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // It starts on the day lent (today). Confirm it: the due date is today.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.text('No due date'), findsNothing);
      // Date lent and due date now both show today.
      expect(find.text(fullDate(DateTime.now())), findsNWidgets(2));
    });
  });

  group('LoanStatusPill', () {
    /// The pill's fill and text colors.
    Future<(Color?, Color?)> colorsOf(
      WidgetTester tester,
      LoanStatus status,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: LoanStatusPill(status)),
        ),
      );
      final fill =
          (tester
                      .widget<DecoratedBox>(find.byType(DecoratedBox).first)
                      .decoration
                  as BoxDecoration)
              .color;
      final text = tester.widget<Text>(find.byType(Text)).style?.color;
      return (fill, text);
    }

    testWidgets('uses the money colors: green, blue and red', (tester) async {
      const colors = AppColors.light;
      expect(await colorsOf(tester, LoanStatus.paid), (
        colors.incomeSoft,
        colors.income,
      ));
      expect(await colorsOf(tester, LoanStatus.partlyPaid), (
        colors.transferSoft,
        colors.transfer,
      ));
      expect(await colorsOf(tester, LoanStatus.overdue), (
        colors.expenseSoft,
        colors.expense,
      ));
    });

    testWidgets('waiting is amber', (tester) async {
      final (fill, _) = await colorsOf(tester, LoanStatus.outstanding);
      expect(fill, AppColors.light.warning.withValues(alpha: 0.18));
    });
  });

  group('dueShortcuts', () {
    test('1 week, 2 weeks and the end of the month', () {
      expect(dueShortcuts(DateTime(2026, 10, 15)), [
        ('1 week', DateTime(2026, 10, 22)),
        ('2 weeks', DateTime(2026, 10, 29)),
        ('End of month', DateTime(2026, 10, 31)),
      ]);
    });

    test('roll over into the next month and year', () {
      expect(dueShortcuts(DateTime(2026, 12, 20)), [
        ('1 week', DateTime(2026, 12, 27)),
        ('2 weeks', DateTime(2027, 1, 3)),
        ('End of month', DateTime(2026, 12, 31)),
      ]);
    });

    test('lent on the last day: the end of month means next month', () {
      expect(dueShortcuts(DateTime(2026, 10, 31)).last, (
        'End of month',
        DateTime(2026, 11, 30),
      ));
    });
  });

  group('Repayment form', () {
    final owed = LoanWithPayments(loan('a', 'Mark', 1000000), [
      payment('a', 400000),
    ]);

    testWidgets('records money paid back into the first account', (
      tester,
    ) async {
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: owed)));

      await tester.enterText(amountField, '1,000');
      await tapSave(tester);

      expect(fake.repaid, [('a', 100000, 'gotyme')]);
    });

    testWidgets('the button and the balance preview follow the amount', (
      tester,
    ) async {
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: owed)));
      expect(
        find.widgetWithText(FilledButton, 'Save repayment'),
        findsOneWidget,
      );

      await tester.enterText(amountField, '1,000');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Record ₱1,000.00 from Mark'),
        findsOneWidget,
      );
      // Money coming in adds to the balance.
      expect(find.text('GoTyme: ₱5,000.00 → ₱6,000.00'), findsOneWidget);
    });

    testWidgets('starts on the account the money was lent from', (
      tester,
    ) async {
      final fromCash = LoanWithPayments(
        loan('a', 'Mark', 1000000, accountId: 'cash'),
        const [],
      );
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: fromCash)));

      await tester.enterText(amountField, '100');
      await tapSave(tester);

      expect(fake.repaid, [('a', 10000, 'cash')]);
    });

    testWidgets('falls back to the first account if that one is gone', (
      tester,
    ) async {
      final fromArchived = LoanWithPayments(
        loan('a', 'Mark', 1000000, accountId: 'old-archived'),
        const [],
      );
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: fromArchived)));

      await tester.enterText(amountField, '100');
      await tapSave(tester);

      expect(fake.repaid, [('a', 10000, 'gotyme')]);
    });

    testWidgets('"Paid in full" fills in what is left', (tester) async {
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: owed)));

      await tester.tap(find.text('Paid in full'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(fake.repaid, [('a', 600000, 'gotyme')]);
    });

    testWidgets('you cannot pay back more than what is owed', (tester) async {
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: owed)));

      await tester.enterText(amountField, '6,000.01');
      await tapSave(tester);

      expect(
        find.textContaining('more than what is still owed (₱6,000.00)'),
        findsOneWidget,
      );
      expect(fake.repaid, isEmpty);
    });

    testWidgets('can be recorded without touching an account', (tester) async {
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: owed)));

      await tester.enterText(amountField, '250');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(fake.repaid, [('a', 25000, null)]);
    });
  });

  group('Loan detail', () {
    testWidgets('shows what is left, the repayments, and the account', (
      tester,
    ) async {
      await pump(
        tester,
        const LoanDetailScreen(loanId: 'a'),
        loans: [
          LoanWithPayments(loan('a', 'Mark', 1000000, accountId: 'gotyme'), [
            payment('a', 400000, accountId: 'cash'),
          ]),
        ],
      );

      expect(find.text('Still owed'), findsOneWidget);
      expect(find.text('₱6,000.00'), findsOneWidget);
      expect(find.text('₱4,000.00 paid back of ₱10,000.00'), findsOneWidget);
      expect(find.text('Taken from GoTyme'), findsOneWidget);
      expect(find.textContaining('Added to Cash'), findsOneWidget);
      expect(find.text('Record repayment'), findsOneWidget);
    });

    testWidgets('a loan with no account says so', (tester) async {
      await pump(
        tester,
        const LoanDetailScreen(loanId: 'a'),
        loans: [LoanWithPayments(loan('a', 'Mark', 1000000), const [])],
      );

      expect(find.text('No account was changed'), findsOneWidget);
      expect(find.text('Nothing paid back yet.'), findsOneWidget);
    });

    testWidgets('a settled loan has no repayment button', (tester) async {
      await pump(
        tester,
        const LoanDetailScreen(loanId: 'a'),
        loans: [
          LoanWithPayments(loan('a', 'Mark', 500000), [payment('a', 500000)]),
        ],
      );

      expect(find.text('Paid back in full'), findsOneWidget);
      expect(find.text('Record repayment'), findsNothing);
    });
  });
}
