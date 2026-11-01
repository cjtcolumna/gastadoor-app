import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/loans/data/loans_provider.dart';
import 'package:gastadoor/features/loans/domain/loan.dart';
import 'package:gastadoor/features/loans/domain/loan_summary.dart';
import 'package:gastadoor/features/loans/presentation/loan_detail_screen.dart';
import 'package:gastadoor/features/loans/presentation/loan_payment_sheet.dart';
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

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
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

    testWidgets('with no loans it invites you to lend money', (tester) async {
      await pump(tester, const LoansScreen());
      expect(find.textContaining('Lent money to a friend?'), findsOneWidget);
      expect(find.text('Nobody owes you right now'), findsOneWidget);
    });

    testWidgets('lending takes the money from the account you pick', (
      tester,
    ) async {
      await pump(tester, const LoansScreen());
      await tester.tap(find.byTooltip('Lend money'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Who borrowed it?'), 'Mark');
      await tester.enterText(field('Amount lent'), '10,000');
      // The first account is picked until you pick another.
      await tapButton(tester, 'Lend');

      expect(fake.lent, [('Mark', 1000000, 'gotyme')]);
    });

    testWidgets('you can pick a different account', (tester) async {
      await pump(tester, const LoansScreen());
      await tester.tap(find.byTooltip('Lend money'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Who borrowed it?'), 'Mark');
      await tester.enterText(field('Amount lent'), '500');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
      await tester.pumpAndSettle();
      await tapButton(tester, 'Lend');

      expect(fake.lent, [('Mark', 50000, 'cash')]);
    });

    testWidgets('turning the switch off leaves every account alone', (
      tester,
    ) async {
      await pump(tester, const LoansScreen());
      await tester.tap(find.byTooltip('Lend money'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Who borrowed it?'), 'Mark');
      await tester.enterText(field('Amount lent'), '10000');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // The account choices are hidden, and the reason is shown.
      expect(find.widgetWithText(ChoiceChip, 'GoTyme'), findsNothing);
      expect(
        find.textContaining('before you started tracking'),
        findsOneWidget,
      );

      await tapButton(tester, 'Lend');
      expect(fake.lent, [('Mark', 1000000, null)]);
    });

    testWidgets('a name and an amount are required', (tester) async {
      await pump(tester, const LoansScreen());
      await tester.tap(find.byTooltip('Lend money'));
      await tester.pumpAndSettle();

      await tapButton(tester, 'Lend');

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(fake.lent, isEmpty);
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

      await tester.enterText(field('Amount paid back'), '1,000');
      await tapButton(tester, 'Save repayment');

      expect(fake.repaid, [('a', 100000, 'gotyme')]);
    });

    testWidgets('"Paid in full" fills in what is left', (tester) async {
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: owed)));

      await tester.tap(find.text('Paid in full'));
      await tester.pumpAndSettle();
      await tapButton(tester, 'Save repayment');

      expect(fake.repaid, [('a', 600000, 'gotyme')]);
    });

    testWidgets('you cannot pay back more than what is owed', (tester) async {
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: owed)));

      await tester.enterText(field('Amount paid back'), '6,000.01');
      await tapButton(tester, 'Save repayment');

      expect(
        find.textContaining('more than what is still owed (₱6,000.00)'),
        findsOneWidget,
      );
      expect(fake.repaid, isEmpty);
    });

    testWidgets('can be recorded without touching an account', (tester) async {
      await pump(tester, Scaffold(body: LoanPaymentSheet(loan: owed)));

      await tester.enterText(field('Amount paid back'), '250');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tapButton(tester, 'Save repayment');

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
