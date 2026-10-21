import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/accounts/domain/balances.dart';

const cash = Account(
  id: 'cash',
  userId: 'u',
  name: 'Cash',
  type: AccountType.cash,
  openingBalanceCents: 100000,
);
const card = Account(
  id: 'card',
  userId: 'u',
  name: 'Card',
  type: AccountType.creditCard,
  openingBalanceCents: -25000,
);

void main() {
  test('balanceOf uses the database balance when there is one', () {
    expect(balanceOf(cash, {'cash': 81050}), 81050);
  });

  test('balanceOf falls back to the starting balance', () {
    expect(balanceOf(cash, {}), 100000);
  });

  test('net worth adds balances and subtracts money owed', () {
    expect(netWorthCents([cash, card], {}), 75000);
    expect(netWorthCents([cash, card], {'cash': 81050}), 56050);
    expect(netWorthCents([], {}), 0);
  });
}
