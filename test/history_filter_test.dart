import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/transactions/domain/history_filter.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';

void main() {
  test('an empty filter is empty and has no search pattern', () {
    expect(HistoryFilter.none.isEmpty, isTrue);
    expect(HistoryFilter.none.activeCount, 0);
    expect(const HistoryFilter(search: '   ').searchPattern, isNull);
  });

  test('search becomes a "contains" pattern with wildcards escaped', () {
    expect(
      const HistoryFilter(search: ' Jollibee ').searchPattern,
      '%Jollibee%',
    );
    // Typed % and _ mean the real characters, not "anything".
    expect(
      const HistoryFilter(search: '50%_off').searchPattern,
      r'%50\%\_off%',
    );
  });

  test('counts active filters (search is separate)', () {
    final f = HistoryFilter(
      month: DateTime(2026, 10),
      kind: TransactionKind.expense,
      search: 'grab',
    );
    expect(f.activeCount, 2);
    expect(f.isEmpty, isFalse);
  });

  test('copyWith can change or clear one field', () {
    final f = HistoryFilter(month: DateTime(2026, 10), accountId: 'cash');
    final cleared = f.copyWith(month: () => null);
    expect(cleared.month, isNull);
    expect(cleared.accountId, 'cash');
    expect(
      f.copyWith(kind: () => TransactionKind.transfer).kind,
      TransactionKind.transfer,
    );
  });

  test('filters with the same settings are equal', () {
    expect(
      HistoryFilter(month: DateTime(2026, 10), search: 'a'),
      HistoryFilter(month: DateTime(2026, 10), search: 'a '),
    );
    expect(
      const HistoryFilter(kind: TransactionKind.income),
      isNot(const HistoryFilter(kind: TransactionKind.expense)),
    );
  });
}
