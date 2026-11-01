import '../../../core/utils/dates.dart';
import 'loan.dart';

enum LoanStatus { outstanding, partlyPaid, paid, overdue }

/// A [Loan] together with its repayments, and the numbers worked out from
/// them. Nothing here is stored: it is all calculated, so it can't drift out
/// of sync with the payments.
class LoanWithPayments {
  const LoanWithPayments(this.loan, this.payments);

  final Loan loan;
  final List<LoanPayment> payments;

  int get paidCents => payments.fold(0, (sum, p) => sum + p.amountCents);

  /// What is still owed to you. Never below zero.
  int get remainingCents {
    final left = loan.amountCents - paidCents;
    return left < 0 ? 0 : left;
  }

  bool get isPaid => remainingCents == 0;

  /// [today] can be passed in so tests don't depend on the real clock.
  LoanStatus statusOn(DateTime today) {
    if (isPaid) return LoanStatus.paid;
    final due = loan.dueOn;
    if (due != null && dateOnly(due).isBefore(dateOnly(today))) {
      return LoanStatus.overdue;
    }
    return paidCents > 0 ? LoanStatus.partlyPaid : LoanStatus.outstanding;
  }
}

/// All the loans of one borrower.
class PersonLoans {
  const PersonLoans(this.person, this.loans);

  /// The name as first typed.
  final String person;
  final List<LoanWithPayments> loans;

  int get owedCents => loans.fold(0, (sum, l) => sum + l.remainingCents);

  /// True when every loan of this person is paid back.
  bool get settled => owedCents == 0;
}

/// Everything still owed to you, in cents.
int totalOwedCents(List<LoanWithPayments> loans) =>
    loans.fold(0, (sum, l) => sum + l.remainingCents);

/// Groups loans by borrower ("Mark" and "mark " are the same person).
/// People who still owe you come first, the one who owes most on top;
/// people who paid everything back come last.
List<PersonLoans> groupByPerson(List<LoanWithPayments> loans) {
  final byKey = <String, List<LoanWithPayments>>{};
  for (final l in loans) {
    byKey.putIfAbsent(l.loan.person.trim().toLowerCase(), () => []).add(l);
  }
  final groups = [
    for (final list in byKey.values)
      PersonLoans(
        list.first.loan.person.trim(),
        // Newest loan first.
        [...list]..sort((a, b) => b.loan.lentOn.compareTo(a.loan.lentOn)),
      ),
  ];
  groups.sort((a, b) {
    if (a.settled != b.settled) return a.settled ? 1 : -1;
    final byOwed = b.owedCents.compareTo(a.owedCents);
    return byOwed != 0
        ? byOwed
        : a.person.toLowerCase().compareTo(b.person.toLowerCase());
  });
  return groups;
}

/// A short line for a loan row: "Overdue · was due Oct 5, 2026",
/// "Partly paid · Due Nov 5, 2026", "Paid back" or "Not paid yet".
/// [today] can be passed in so tests don't depend on the real clock.
String statusLine(LoanWithPayments loan, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final status = loan.statusOn(now);
  final due = loan.loan.dueOn;
  return switch (status) {
    LoanStatus.paid => 'Paid back',
    LoanStatus.overdue => 'Overdue · was due ${friendlyDate(due!, today: now)}',
    LoanStatus.partlyPaid || LoanStatus.outstanding => [
      if (status == LoanStatus.partlyPaid) 'Partly paid',
      if (due != null) 'Due ${friendlyDate(due, today: now)}',
      if (status == LoanStatus.outstanding && due == null) 'Not paid yet',
    ].join(' · '),
  };
}
