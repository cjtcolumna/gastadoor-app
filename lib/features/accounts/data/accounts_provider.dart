import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/account.dart';
import 'accounts_repository.dart';

/// The signed-in user's active accounts, shared with every screen.
/// Screens call the methods below to change accounts; the list reloads after.
final accountsProvider = AsyncNotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
);

/// Current balance of each account (in cents), keyed by account id.
/// Reloads whenever the account list changes.
final accountBalancesProvider = FutureProvider<Map<String, int>>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  if (accounts.isEmpty) return {};
  return ref.watch(accountsRepositoryProvider).fetchBalances();
});

/// Accounts the user archived. Reloads whenever the active list changes,
/// so archiving or restoring updates both lists at once.
final archivedAccountsProvider = FutureProvider<List<Account>>((ref) async {
  await ref.watch(accountsProvider.future);
  if (!ref.watch(supabaseReadyProvider)) return [];
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(accountsRepositoryProvider).fetchArchived();
});

class AccountsNotifier extends AsyncNotifier<List<Account>> {
  AccountsRepository get _repo => ref.read(accountsRepositoryProvider);

  @override
  Future<List<Account>> build() async {
    if (!ref.watch(supabaseReadyProvider)) return [];
    // Watching the user means this reloads when someone signs in or out.
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];

    final accounts = await _repo.fetchActive();
    if (accounts.isEmpty && !await _repo.hasAny()) {
      // Brand-new user: start them with a Cash account.
      await _repo.create(name: 'Cash', type: AccountType.cash);
      return _repo.fetchActive();
    }
    return accounts;
  }

  Future<void> add({
    required String name,
    required AccountType type,
    required int openingBalanceCents,
    String? parentId,
  }) async {
    await _repo.create(
      name: name,
      type: type,
      openingBalanceCents: openingBalanceCents,
      parentId: parentId,
    );
    await _reload();
  }

  Future<void> save(Account account) async {
    await _repo.update(account);
    await _reload();
  }

  Future<void> archive(String id) async {
    await _repo.archive(id);
    await _reload();
  }

  Future<void> restore(Account account) async {
    await _repo.restore(account);
    await _reload();
  }

  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
  }
}
