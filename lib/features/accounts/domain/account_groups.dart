import 'account.dart';
import 'balances.dart';

/// An account plus its sub-accounts (pockets), e.g.
/// GoTyme -> [Travel, Emergency Fund]. Accounts without pockets are a
/// group with no children.
class AccountGroup {
  const AccountGroup(this.account, [this.children = const []]);

  /// The main (parent) account.
  final Account account;

  /// Its sub-accounts, oldest first. Empty for a normal account.
  final List<Account> children;

  bool get hasChildren => children.isNotEmpty;

  /// The parent first, then its sub-accounts.
  List<Account> get members => [account, ...children];

  /// The parent's own balance plus every sub-account's balance.
  int totalCents(Map<String, int> balances) => netWorthCents(members, balances);
}

/// Puts each sub-account under its parent, keeping the original order.
///
/// A sub-account whose parent isn't in [accounts] (for example, only the
/// pocket is archived) is shown as its own group, so nothing goes missing.
List<AccountGroup> groupAccounts(List<Account> accounts) {
  final ids = {for (final a in accounts) a.id};
  final childrenOf = <String, List<Account>>{};
  for (final a in accounts) {
    final parentId = a.parentId;
    if (parentId != null && ids.contains(parentId)) {
      (childrenOf[parentId] ??= []).add(a);
    }
  }
  return [
    for (final a in accounts)
      if (a.parentId == null || !ids.contains(a.parentId))
        AccountGroup(a, childrenOf[a.id] ?? const []),
  ];
}

/// Accounts in display order: each parent followed by its sub-accounts.
List<Account> inGroupOrder(List<Account> accounts) => [
  for (final group in groupAccounts(accounts)) ...group.members,
];

/// The name to show for [account]: "GoTyme › Travel" for a sub-account
/// (when its parent is in [all]), or just "GoTyme".
String accountLabel(Account account, List<Account> all) {
  final parentId = account.parentId;
  if (parentId == null) return account.name;
  final parent = all.where((a) => a.id == parentId).firstOrNull;
  return parent == null ? account.name : '${parent.name} › ${account.name}';
}

/// [id] plus the ids of its sub-accounts. Used by the History filter, so
/// picking "GoTyme" also shows what happened in its pockets.
Set<String> idWithChildren(String id, List<Account> all) => {
  id,
  for (final a in all)
    if (a.parentId == id) a.id,
};

/// Accounts that [editing] could be moved inside: top-level accounts other
/// than itself. Empty if [editing] has pockets of its own (one level only).
List<Account> parentOptions(Account? editing, List<Account> active) {
  if (editing != null && active.any((a) => a.parentId == editing.id)) {
    return const [];
  }
  return [
    for (final a in active)
      if (a.parentId == null && a.id != editing?.id) a,
  ];
}
