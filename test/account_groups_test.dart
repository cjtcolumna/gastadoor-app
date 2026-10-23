import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/accounts/domain/account_groups.dart';
import 'package:gastadoor/features/accounts/domain/balances.dart';

Account account(String id, String name, {String? parentId}) => Account(
  id: id,
  userId: 'u',
  name: name,
  type: AccountType.bank,
  parentId: parentId,
);

final gotyme = account('g', 'GoTyme');
final travel = account('t', 'Travel', parentId: 'g');
final emergency = account('e', 'Emergency Fund', parentId: 'g');
final cash = account('c', 'Cash');

// The list comes from the database oldest first, so pockets can be
// anywhere in it.
final all = [gotyme, cash, travel, emergency];

const balances = {
  'g': 5000000, // ₱50,000
  't': 700000, // ₱7,000
  'e': 200000, // ₱2,000
  'c': 150000, // ₱1,500
};

void main() {
  group('groupAccounts', () {
    test('puts each pocket under its parent, keeping the order', () {
      final groups = groupAccounts(all);
      expect(groups.map((g) => g.account.name), ['GoTyme', 'Cash']);
      expect(groups[0].children.map((a) => a.name), [
        'Travel',
        'Emergency Fund',
      ]);
      expect(groups[1].hasChildren, isFalse);
    });

    test('a pocket whose parent is missing still shows up', () {
      final groups = groupAccounts([travel, cash]);
      expect(groups.map((g) => g.account.name), ['Travel', 'Cash']);
    });
  });

  test('GoTyme total = its own ₱50,000 + ₱7,000 + ₱2,000 = ₱59,000', () {
    final gotymeGroup = groupAccounts(all).first;
    expect(gotymeGroup.totalCents(balances), 5900000);
  });

  test('net worth counts each peso once (no double counting)', () {
    final groupTotals = groupAccounts(all)
        .fold(0, (sum, g) => sum + g.totalCents(balances));
    expect(groupTotals, netWorthCents(all, balances));
    expect(groupTotals, 6050000);
  });

  test('inGroupOrder lists each parent followed by its pockets', () {
    expect(inGroupOrder(all).map((a) => a.name), [
      'GoTyme',
      'Travel',
      'Emergency Fund',
      'Cash',
    ]);
  });

  test('accountLabel shows the parent for pockets', () {
    expect(accountLabel(travel, all), 'GoTyme › Travel');
    expect(accountLabel(gotyme, all), 'GoTyme');
    // Parent unknown: just the pocket's own name.
    expect(accountLabel(travel, [travel]), 'Travel');
  });

  test('idWithChildren includes the pockets', () {
    expect(idWithChildren('g', all), {'g', 't', 'e'});
    expect(idWithChildren('t', all), {'t'});
  });

  group('parentOptions (one level only)', () {
    test('a new account can go inside any top-level account', () {
      expect(parentOptions(null, all).map((a) => a.name), ['GoTyme', 'Cash']);
    });

    test("an account can't go inside itself or another pocket", () {
      expect(parentOptions(cash, all).map((a) => a.name), ['GoTyme']);
      expect(parentOptions(travel, all).map((a) => a.name), ['GoTyme', 'Cash']);
    });

    test('an account that has pockets cannot become a pocket', () {
      expect(parentOptions(gotyme, all), isEmpty);
    });
  });
}
