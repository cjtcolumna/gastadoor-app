import 'transaction.dart';

/// A transaction plus the names of its account and category,
/// ready to show in a list.
class TransactionListItem {
  const TransactionListItem({
    required this.transaction,
    required this.accountName,
    this.categoryName,
  });

  final Transaction transaction;
  final String accountName;
  final String? categoryName;

  /// Builds an item from a Supabase row that includes
  /// `accounts(name)` and `categories(name)`.
  factory TransactionListItem.fromRow(Map<String, dynamic> row) {
    final account = row['accounts'] as Map<String, dynamic>?;
    final category = row['categories'] as Map<String, dynamic>?;
    return TransactionListItem(
      transaction: Transaction.fromJson(row),
      accountName: account?['name'] as String? ?? 'Unknown account',
      categoryName: category?['name'] as String?,
    );
  }
}

/// One page of history: up to [pageSize] items, plus how many exist in total.
class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.page,
    required this.totalCount,
    this.pageSize = defaultPageSize,
  });

  static const defaultPageSize = 20;

  final List<TransactionListItem> items;

  /// 0 for the first page, 1 for the second, and so on.
  final int page;
  final int totalCount;
  final int pageSize;

  /// How many pages there are. Always at least 1, even with no data.
  int get pageCount => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();

  bool get hasPrevious => page > 0;
  bool get hasNext => page < pageCount - 1;

  /// Row numbers shown on this page, e.g. (21, 40). (0, 0) when empty.
  (int, int) get shownRange => items.isEmpty
      ? (0, 0)
      : (page * pageSize + 1, page * pageSize + items.length);

  /// First and last row index (0-based, inclusive) to ask the database for.
  static (int, int) rowRange(int page, {int pageSize = defaultPageSize}) =>
      (page * pageSize, page * pageSize + pageSize - 1);
}
