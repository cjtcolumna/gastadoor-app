import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_groups.dart';
import 'transaction.dart';

/// A transaction plus the names of its account and category,
/// ready to show in a list.
class TransactionListItem {
  const TransactionListItem({
    required this.transaction,
    required this.accountName,
    this.toAccountName,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  final Transaction transaction;
  final String accountName;

  /// Transfers only: where the money went.
  final String? toAccountName;
  final String? categoryName;

  /// Icon and color names, e.g. 'restaurant' and 'orange', or null.
  final String? categoryIcon;
  final String? categoryColor;

  /// Builds an item from a Supabase row that includes
  /// `account:accounts(name)`, `to_account:accounts(name)`,
  /// and `categories(name, icon, color)`.
  factory TransactionListItem.fromRow(Map<String, dynamic> row) {
    final account = row['account'] as Map<String, dynamic>?;
    final toAccount = row['to_account'] as Map<String, dynamic>?;
    final category = row['categories'] as Map<String, dynamic>?;
    return TransactionListItem(
      transaction: Transaction.fromJson(row),
      accountName: account?['name'] as String? ?? 'Unknown account',
      toAccountName: toAccount?['name'] as String?,
      categoryName: category?['name'] as String?,
      categoryIcon: category?['icon'] as String?,
      categoryColor: category?['color'] as String?,
    );
  }

  /// A copy with different account names (everything else the same).
  TransactionListItem withAccountNames(String accountName, String? toName) =>
      TransactionListItem(
        transaction: transaction,
        accountName: accountName,
        toAccountName: toName,
        categoryName: categoryName,
        categoryIcon: categoryIcon,
        categoryColor: categoryColor,
      );
}

/// Renames pockets in [items] to "GoTyme › Travel", using [all] accounts
/// (active and archived). Accounts it doesn't know keep their name.
List<TransactionListItem> labelAccounts(
  List<TransactionListItem> items,
  List<Account> all,
) {
  final byId = {for (final a in all) a.id: a};
  String? label(String? id, String? fallback) {
    final account = byId[id];
    return account == null ? fallback : accountLabel(account, all);
  }

  return [
    for (final item in items)
      item.withAccountNames(
        label(item.transaction.accountId, item.accountName)!,
        label(item.transaction.toAccountId, item.toAccountName),
      ),
  ];
}

/// A day's total: income minus expenses. Transfers don't change it,
/// because the money stays yours.
int dayNetCents(List<TransactionListItem> items) {
  var net = 0;
  for (final item in items) {
    final t = item.transaction;
    switch (t.kind) {
      case TransactionKind.income:
        net += t.amountCents;
      case TransactionKind.expense:
        net -= t.amountCents;
      case TransactionKind.transfer:
        break;
    }
  }
  return net;
}

/// Splits a newest-first list into days, keeping the order:
/// [(Oct 22, [items...]), (Oct 21, [items...]), ...].
List<(DateTime, List<TransactionListItem>)> groupByDay(
  List<TransactionListItem> items,
) {
  final groups = <(DateTime, List<TransactionListItem>)>[];
  for (final item in items) {
    final d = item.transaction.occurredOn;
    final day = DateTime(d.year, d.month, d.day);
    if (groups.isNotEmpty && groups.last.$1 == day) {
      groups.last.$2.add(item);
    } else {
      groups.add((day, [item]));
    }
  }
  return groups;
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
