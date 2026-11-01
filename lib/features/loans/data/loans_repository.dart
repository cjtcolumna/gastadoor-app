import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/dates.dart';
import '../domain/loan.dart';

/// All Supabase calls for the `loans` and `loan_payments` tables.
/// Row Level Security keeps each user to their own rows, and the database
/// fills in `user_id` for us.
class LoansRepository {
  LoansRepository(this._client);

  final SupabaseClient _client;

  /// Newest loan first.
  Future<List<Loan>> fetchLoans() async {
    final rows = await _client
        .from('loans')
        .select()
        .order('lent_on', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(Loan.fromJson).toList();
  }

  /// Oldest payment first.
  Future<List<LoanPayment>> fetchPayments() async {
    final rows = await _client
        .from('loan_payments')
        .select()
        .order('paid_on')
        .order('created_at');
    return rows.map(LoanPayment.fromJson).toList();
  }

  /// [accountId] null means "don't change any account".
  Future<void> createLoan({
    required String person,
    required int amountCents,
    required DateTime lentOn,
    DateTime? dueOn,
    String? note,
    String? accountId,
  }) async {
    await _client.from('loans').insert({
      'person': person.trim(),
      'amount_cents': amountCents,
      'lent_on': toDbDate(lentOn),
      'due_on': dueOn == null ? null : toDbDate(dueOn),
      'note': _cleanNote(note),
      'account_id': accountId,
    });
  }

  /// Changes who, when it is due, and the note. The amount and account stay
  /// as they were, so balances never shift behind your back.
  Future<void> updateDetails(Loan loan) async {
    await _client
        .from('loans')
        .update({
          'person': loan.person.trim(),
          'due_on': loan.dueOn == null ? null : toDbDate(loan.dueOn!),
          'note': _cleanNote(loan.note),
        })
        .eq('id', loan.id);
  }

  /// Deletes the loan and (by the database) all of its payments.
  Future<void> deleteLoan(String id) async {
    await _client.from('loans').delete().eq('id', id);
  }

  Future<void> createPayment({
    required String loanId,
    required int amountCents,
    required DateTime paidOn,
    String? note,
    String? accountId,
  }) async {
    await _client.from('loan_payments').insert({
      'loan_id': loanId,
      'amount_cents': amountCents,
      'paid_on': toDbDate(paidOn),
      'note': _cleanNote(note),
      'account_id': accountId,
    });
  }

  Future<void> deletePayment(String id) async {
    await _client.from('loan_payments').delete().eq('id', id);
  }

  /// An empty note is saved as "no note".
  String? _cleanNote(String? note) {
    final text = note?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

final loansRepositoryProvider = Provider<LoansRepository>(
  (ref) => LoansRepository(ref.watch(supabaseClientProvider)),
);
