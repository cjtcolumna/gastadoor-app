import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/dates.dart';
import '../domain/transaction.dart';
import '../domain/month_totals.dart';
import '../domain/transaction_draft.dart';
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
        .gte('occurred_on', toDbDate(from))
        .lte('occurred_on', toDbDate(to))
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
        // Two links point to `accounts` (From and To), so each one names
        // which database link (foreign key) to follow, and gets a nickname.
        .select(
          '*, '
          'account:accounts!transactions_account_id_user_id_fkey(name), '
          'to_account:accounts!transactions_to_account_id_user_id_fkey(name), '
          'categories(name, icon, color)',
        )
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

  Future<void> create(TransactionDraft draft) async {
    await _client.from('transactions').insert(draft.toRow());
  }

  Future<void> update(String id, TransactionDraft draft) async {
    await _client.from('transactions').update(draft.toRow()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(supabaseClientProvider)),
);

/// Every transaction in the current calendar month. Shared by the month
/// totals on Home and by budgets, so it's only loaded once.
/// Empty when Supabase is not configured or nobody is signed in.
final monthTransactionsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  if (!ref.watch(supabaseReadyProvider)) return const [];
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return const [];

  final now = DateTime.now();
  final first = DateTime(now.year, now.month);
  final last = DateTime(now.year, now.month + 1, 0);
  return ref.watch(transactionsRepositoryProvider).fetchBetween(first, last);
});

/// Money in and money out (in cents) for the current calendar month.
final monthTotalsProvider = FutureProvider<MonthTotals>((ref) async {
  final txns = await ref.watch(monthTransactionsProvider.future);
  return MonthTotals.from(txns);
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
