import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/account.dart';
import 'accounts_repository.dart';

/// The signed-in user's active accounts, shared with every screen.
/// Screens call the methods below to change accounts; the list reloads after.
final accountsProvider = AsyncNotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
);

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
  }) async {
    await _repo.create(
      name: name,
      type: type,
      openingBalanceCents: openingBalanceCents,
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

  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
  }
}
