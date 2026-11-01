import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../accounts/data/accounts_provider.dart';
import '../domain/loan.dart';
import '../domain/loan_summary.dart';
import 'loans_repository.dart';

/// The signed-in user's loans, each with its repayments. Screens call the
/// methods below to change them; everything reloads after each change.
final loansProvider =
    AsyncNotifierProvider<LoansNotifier, List<LoanWithPayments>>(
      LoansNotifier.new,
    );

/// One loan by id, or null if it isn't there (for example just deleted).
final loanByIdProvider = Provider.family<AsyncValue<LoanWithPayments?>, String>(
  (ref, id) => ref
      .watch(loansProvider)
      .whenData((all) => all.where((l) => l.loan.id == id).firstOrNull),
);

class LoansNotifier extends AsyncNotifier<List<LoanWithPayments>> {
  LoansRepository get _repo => ref.read(loansRepositoryProvider);

  @override
  Future<List<LoanWithPayments>> build() async {
    if (!ref.watch(supabaseReadyProvider)) return [];
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];

    final loans = await _repo.fetchLoans();
    final payments = await _repo.fetchPayments();
    return [
      for (final loan in loans)
        LoanWithPayments(loan, [
          for (final p in payments)
            if (p.loanId == loan.id) p,
        ]),
    ];
  }

  /// [accountId] null means "don't change any account".
  Future<void> add({
    required String person,
    required int amountCents,
    required DateTime lentOn,
    DateTime? dueOn,
    String? note,
    String? accountId,
  }) async {
    await _repo.createLoan(
      person: person,
      amountCents: amountCents,
      lentOn: lentOn,
      dueOn: dueOn,
      note: note,
      accountId: accountId,
    );
    await _reload();
  }

  Future<void> saveDetails(Loan loan) async {
    await _repo.updateDetails(loan);
    await _reload();
  }

  Future<void> remove(String id) async {
    await _repo.deleteLoan(id);
    await _reload();
  }

  Future<void> addPayment({
    required String loanId,
    required int amountCents,
    required DateTime paidOn,
    String? note,
    String? accountId,
  }) async {
    await _repo.createPayment(
      loanId: loanId,
      amountCents: amountCents,
      paidOn: paidOn,
      note: note,
      accountId: accountId,
    );
    await _reload();
  }

  Future<void> removePayment(String id) async {
    await _repo.deletePayment(id);
    await _reload();
  }

  Future<void> _reload() async {
    // Loans and repayments move money in and out of accounts, so the
    // balances have to be read again too.
    ref.invalidate(accountBalancesProvider);
    ref.invalidateSelf();
    await future;
  }
}
