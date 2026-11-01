import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/loans/domain/loan.dart';
import 'package:gastadoor/features/loans/domain/loan_summary.dart';

Loan loan(
  String id,
  String person,
  int cents, {
  DateTime? lentOn,
  DateTime? dueOn,
}) => Loan(
  id: id,
  userId: 'u',
  person: person,
  amountCents: cents,
  lentOn: lentOn ?? DateTime(2026, 10, 1),
  dueOn: dueOn,
);

LoanPayment pay(String loanId, int cents) => LoanPayment(
  id: 'p$loanId$cents',
  userId: 'u',
  loanId: loanId,
  amountCents: cents,
  paidOn: DateTime(2026, 10, 10),
);

void main() {
  final today = DateTime(2026, 11, 1);

  group('remaining and paid', () {
    test('nothing paid: everything is still owed', () {
      final l = LoanWithPayments(loan('a', 'Mark', 1000000), const []);
      expect(l.paidCents, 0);
      expect(l.remainingCents, 1000000);
      expect(l.isPaid, isFalse);
    });

    test('repayments add up and lower what is owed', () {
      final l = LoanWithPayments(loan('a', 'Mark', 1000000), [
        pay('a', 250000),
        pay('a', 150000),
      ]);
      expect(l.paidCents, 400000);
      expect(l.remainingCents, 600000);
    });

    test('paying it all back settles it', () {
      final l = LoanWithPayments(loan('a', 'Mark', 500000), [pay('a', 500000)]);
      expect(l.remainingCents, 0);
      expect(l.isPaid, isTrue);
    });
  });

  group('status', () {
    test('not paid yet', () {
      final l = LoanWithPayments(loan('a', 'Mark', 1000), const []);
      expect(l.statusOn(today), LoanStatus.outstanding);
    });

    test('partly paid', () {
      final l = LoanWithPayments(loan('a', 'Mark', 1000), [pay('a', 100)]);
      expect(l.statusOn(today), LoanStatus.partlyPaid);
    });

    test('paid wins even when the due date has passed', () {
      final l = LoanWithPayments(
        loan('a', 'Mark', 1000, dueOn: DateTime(2026, 10, 5)),
        [pay('a', 1000)],
      );
      expect(l.statusOn(today), LoanStatus.paid);
    });

    test('overdue once the due day has passed, but not on the due day', () {
      final l = LoanWithPayments(
        loan('a', 'Mark', 1000, dueOn: DateTime(2026, 11, 1)),
        const [],
      );
      expect(l.statusOn(DateTime(2026, 11, 1)), LoanStatus.outstanding);
      expect(l.statusOn(DateTime(2026, 11, 2)), LoanStatus.overdue);
    });

    test('a partly paid loan can still be overdue', () {
      final l = LoanWithPayments(
        loan('a', 'Mark', 1000, dueOn: DateTime(2026, 10, 20)),
        [pay('a', 100)],
      );
      expect(l.statusOn(today), LoanStatus.overdue);
    });
  });

  group('status words', () {
    LoanWithPayments make(DateTime? due, [List<LoanPayment> p = const []]) =>
        LoanWithPayments(loan('a', 'Mark', 1000, dueOn: due), p);

    test('each status has a label for its pill', () {
      expect(statusLabel(make(null).statusOn(today)), 'Not paid yet');
      expect(
        statusLabel(make(null, [pay('a', 100)]).statusOn(today)),
        'Partly paid',
      );
      expect(
        statusLabel(make(DateTime(2026, 10, 5)).statusOn(today)),
        'Overdue',
      );
      expect(
        statusLabel(make(null, [pay('a', 1000)]).statusOn(today)),
        'Paid back',
      );
    });

    test('the due date note: upcoming, passed, none, or paid', () {
      expect(dueNote(make(null), today: today), isNull);
      expect(
        dueNote(make(DateTime(2026, 11, 20)), today: today),
        'Due Nov 20, 2026',
      );
      expect(
        dueNote(make(DateTime(2026, 11, 20), [pay('a', 100)]), today: today),
        'Due Nov 20, 2026',
      );
      expect(
        dueNote(make(DateTime(2026, 10, 5)), today: today),
        'was due Oct 5, 2026',
      );
      // Once it is paid back, the due date no longer matters.
      expect(
        dueNote(make(DateTime(2026, 10, 5), [pay('a', 1000)]), today: today),
        isNull,
      );
    });
  });

  group('totals and grouping', () {
    final mark1 = LoanWithPayments(loan('a', 'Mark', 1000000), [
      pay('a', 400000),
    ]);
    final mark2 = LoanWithPayments(
      loan('b', ' mark ', 200000, lentOn: DateTime(2026, 10, 20)),
      const [],
    );
    final ana = LoanWithPayments(loan('c', 'Ana', 300000), [pay('c', 300000)]);
    final joy = LoanWithPayments(loan('d', 'Joy', 900000), const []);

    test('the total owed adds up what is left on every loan', () {
      expect(
        totalOwedCents([mark1, mark2, ana, joy]),
        600000 + 200000 + 900000,
      );
      expect(totalOwedCents(const []), 0);
    });

    test('the same person is grouped, ignoring case and spaces', () {
      final groups = groupByPerson([mark1, mark2]);
      expect(groups, hasLength(1));
      expect(groups.single.person, 'Mark');
      expect(groups.single.owedCents, 800000);
    });

    test('newest loan first inside a person', () {
      final loans = groupByPerson([mark1, mark2]).single.loans;
      expect(loans.map((l) => l.loan.id), ['b', 'a']);
    });

    test('who owes most comes first, and settled people go last', () {
      final groups = groupByPerson([ana, mark1, mark2, joy]);
      expect(groups.map((g) => g.person), ['Joy', 'Mark', 'Ana']);
      expect(groups.last.settled, isTrue);
    });
  });
}
