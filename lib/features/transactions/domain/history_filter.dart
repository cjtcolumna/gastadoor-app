import 'transaction.dart';

/// What the History list is narrowed down to. Every field is optional:
/// an empty filter shows everything.
///
/// It compares by value (two filters with the same settings are equal),
/// so Riverpod can remember each filter's results separately.
class HistoryFilter {
  const HistoryFilter({
    this.month,
    this.kind,
    this.accountId,
    this.categoryId,
    this.search = '',
  });

  static const none = HistoryFilter();

  /// The first day of a month, or null for "All time".
  final DateTime? month;

  /// Expense, income, or transfer only (null = all kinds).
  final TransactionKind? kind;

  /// Only money that went in or out of this account (including transfers).
  final String? accountId;
  final String? categoryId;

  /// Words to look for in notes.
  final String search;

  /// How many filters are switched on (the search box doesn't count).
  int get activeCount =>
      [month, kind, accountId, categoryId].where((x) => x != null).length;

  bool get isEmpty => activeCount == 0 && search.trim().isEmpty;

  /// A copy with some fields changed. Pass a function returning null to
  /// clear a field: `filter.copyWith(month: () => null)`.
  HistoryFilter copyWith({
    DateTime? Function()? month,
    TransactionKind? Function()? kind,
    String? Function()? accountId,
    String? Function()? categoryId,
    String? search,
  }) => HistoryFilter(
    month: month == null ? this.month : month(),
    kind: kind == null ? this.kind : kind(),
    accountId: accountId == null ? this.accountId : accountId(),
    categoryId: categoryId == null ? this.categoryId : categoryId(),
    search: search ?? this.search,
  );

  /// The search text as a database "contains" pattern, e.g. "%jollibee%".
  /// `%` and `_` are wildcards in such patterns, so typed ones are escaped
  /// to mean the plain characters. Null when the search box is empty.
  String? get searchPattern {
    final text = search.trim();
    if (text.isEmpty) return null;
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryFilter &&
      other.month == month &&
      other.kind == kind &&
      other.accountId == accountId &&
      other.categoryId == categoryId &&
      other.search.trim() == search.trim();

  /// Readable text for debugging and test failures.
  @override
  String toString() =>
      'HistoryFilter(month: $month, kind: ${kind?.name}, '
      'accountId: $accountId, categoryId: $categoryId, search: "$search")';

  @override
  int get hashCode =>
      Object.hash(month, kind, accountId, categoryId, search.trim());
}
