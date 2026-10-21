import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../domain/transaction.dart';
import '../domain/transaction_page.dart';

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

  /// One page of transactions, newest first, with account and category names.
  /// [page] starts at 0. Also asks Supabase for the total number of rows,
  /// so the screen can show "Page 2 of 3".
  Future<TransactionPage> fetchPage(
    int page, {
    int pageSize = TransactionPage.defaultPageSize,
  }) async {
    final (from, to) = TransactionPage.rowRange(page, pageSize: pageSize);
    final response = await _client
        .from('transactions')
        .select('*, accounts(name), categories(name)')
        .order('occurred_on', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to)
        .count(CountOption.exact);

    return TransactionPage(
      items: response.data.map(TransactionListItem.fromRow).toList(),
      page: page,
      totalCount: response.count,
      pageSize: pageSize,
    );
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

/// One page of history. `ref.watch(historyPageProvider(0))` is page 1,
/// `historyPageProvider(1)` is page 2, and so on.
final historyPageProvider = FutureProvider.family<TransactionPage, int>((
  ref,
  page,
) async {
  if (!ref.watch(supabaseReadyProvider)) {
    return TransactionPage(items: const [], page: page, totalCount: 0);
  }
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return TransactionPage(items: const [], page: page, totalCount: 0);
  }
  return ref.watch(transactionsRepositoryProvider).fetchPage(page);
});
