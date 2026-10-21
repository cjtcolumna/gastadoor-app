import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../domain/transaction.dart';

class TransactionsRepository {
  TransactionsRepository(this._client);

  final SupabaseClient _client;

  /// Transactions for the signed-in user between [from] and [to] (inclusive).
  /// Row Level Security makes sure only the user's own rows come back.
  Future<List<Transaction>> fetchBetween(DateTime from, DateTime to) async {
    final rows = await _client
        .from('transactions')
        .select()
        .gte('occurred_on', _date(from))
        .lte('occurred_on', _date(to))
        .order('occurred_on', ascending: false);
    return rows.map(Transaction.fromJson).toList();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(supabaseClientProvider)),
);

/// Total spent (in cents) in the current calendar month.
/// Returns 0 when Supabase is not configured or nobody is signed in.
final monthSpentCentsProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(supabaseReadyProvider)) return 0;
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return 0;

  final now = DateTime.now();
  final first = DateTime(now.year, now.month);
  final last = DateTime(now.year, now.month + 1, 0);
  final txns = await ref
      .watch(transactionsRepositoryProvider)
      .fetchBetween(first, last);
  return txns
      .where((t) => t.kind == TransactionKind.expense)
      .fold<int>(0, (sum, t) => sum + t.amountCents);
});
