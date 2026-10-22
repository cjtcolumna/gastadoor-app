import 'account.dart';

/// The current balance of [account] in cents.
/// Falls back to the starting balance if the database has no number for it.
int balanceOf(Account account, Map<String, int> balances) =>
    balances[account.id] ?? account.openingBalanceCents;

/// Net worth = all account balances added together.
/// Money you owe (negative balances, like a credit card) lowers it.
int netWorthCents(List<Account> accounts, Map<String, int> balances) =>
    accounts.fold(0, (sum, a) => sum + balanceOf(a, balances));
