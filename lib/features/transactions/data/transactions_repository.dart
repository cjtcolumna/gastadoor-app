import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/dates.dart';
import '../domain/transaction.dart';
import '../domain/history_filter.dart';
import '../domain/month_totals.dart';
import '../domain/spending_breakdown.dart';
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
    HistoryFilter filter = HistoryFilter.none,
    int pageSize = TransactionPage.defaultPageSize,
  }) async {
    final (from, to) = TransactionPage.rowRange(page, pageSize: pageSize);
    var query = _client
        .from('transactions')
        // Two links point to `accounts` (From and To), so each one names
        // which database link (foreign key) to follow, and gets a nickname.
        .select(
          '*, '
          'account:accounts!transactions_account_id_user_id_fkey(name), '
          'to_account:accounts!transactions_to_account_id_user_id_fkey(name), '
          'categories(name, icon, color)',
        );

    // Each filter narrows the search inside the database, so only
    // matching rows (and the right total) come back.
    final month = filter.month;
    if (month != null) {
      query = query
          .gte('occurred_on', toDbDate(month))
          .lte(
            'occurred_on',
            toDbDate(DateTime(month.year, month.month + 1, 0)),
          );
    }
    final kind = filter.kind;
    if (kind != null) query = query.eq('kind', kind.name);
    final accountId = filter.accountId;
    if (accountId != null) {
      // Money from this account, or transferred into it.
      query = query.or('account_id.eq.$accountId,to_account_id.eq.$accountId');
    }
    final categoryId = filter.categoryId;
    if (categoryId != null) query = query.eq('category_id', categoryId);
    final pattern = filter.searchPattern;
    if (pattern != null) query = query.ilike('note', pattern);

    final response = await query
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

/// Every transaction in one calendar month. Pass the month's first day:
/// `transactionsInMonthProvider(DateTime(2026, 10))`.
/// Empty when Supabase is not configured or nobody is signed in.
final transactionsInMonthProvider =
    FutureProvider.family<List<Transaction>, DateTime>((ref, month) async {
      if (!ref.watch(supabaseReadyProvider)) return const [];
      final user = await ref.watch(currentUserProvider.future);
      if (user == null) return const [];

      final first = DateTime(month.year, month.month);
      final last = DateTime(month.year, month.month + 1, 0);
      return ref
          .watch(transactionsRepositoryProvider)
          .fetchBetween(first, last);
    });

/// The first day of the current month.
DateTime thisMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

/// This month's transactions. Shared by the month totals on Home, budgets,
/// and the spending chart, so they're only loaded once.
final monthTransactionsProvider = FutureProvider<List<Transaction>>(
  (ref) => ref.watch(transactionsInMonthProvider(thisMonth()).future),
);

/// Income and spending for each of the last 6 months (oldest first),
/// loaded in one request.
final sixMonthTrendProvider = FutureProvider<List<MonthPoint>>((ref) async {
  if (!ref.watch(supabaseReadyProvider)) return const [];
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return const [];

  final last = thisMonth();
  final first = DateTime(last.year, last.month - 5);
  final end = DateTime(last.year, last.month + 1, 0);
  final txns = await ref
      .watch(transactionsRepositoryProvider)
      .fetchBetween(first, end);
  return monthlyTrend(txns, lastMonth: last);
});

/// Money in and money out (in cents) for the current calendar month.
final monthTotalsProvider = FutureProvider<MonthTotals>((ref) async {
  final txns = await ref.watch(monthTransactionsProvider.future);
  return MonthTotals.from(txns);
});

/// One page of history for a set of filters.
/// `historyPageProvider((HistoryFilter.none, 0))` is page 1 of everything;
/// each different filter + page pair is loaded and remembered separately.
final historyPageProvider =
    FutureProvider.family<TransactionPage, HistoryQuery>((ref, query) async {
      final (filter, page) = query;
      if (!ref.watch(supabaseReadyProvider)) {
        return TransactionPage(items: const [], page: page, totalCount: 0);
      }
      final user = await ref.watch(currentUserProvider.future);
      if (user == null) {
        return TransactionPage(items: const [], page: page, totalCount: 0);
      }
      return ref
          .watch(transactionsRepositoryProvider)
          .fetchPage(page, filter: filter);
    });

/// Which filters, and which page (0 = first).
typedef HistoryQuery = (HistoryFilter filter, int page);
