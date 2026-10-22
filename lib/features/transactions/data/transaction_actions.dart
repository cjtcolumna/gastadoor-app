import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/accounts_provider.dart';
import '../domain/transaction_draft.dart';
import 'transactions_repository.dart';

/// Add, edit, or delete a transaction, then refresh every screen that
/// shows money: Home (net worth, spent this month), Accounts, and History.
class TransactionActions {
  TransactionActions(this._ref);

  final Ref _ref;

  TransactionsRepository get _repo => _ref.read(transactionsRepositoryProvider);

  Future<void> add(TransactionDraft draft) async {
    await _repo.create(draft);
    _refreshScreens();
  }

  Future<void> update(String id, TransactionDraft draft) async {
    await _repo.update(id, draft);
    _refreshScreens();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refreshScreens();
  }

  /// "Invalidate" means: throw away the saved answer and fetch it again
  /// the next time a screen asks.
  void _refreshScreens() {
    _ref.invalidate(accountBalancesProvider);
    _ref.invalidate(monthTotalsProvider);
    _ref.invalidate(historyPageProvider);
  }
}

final transactionActionsProvider = Provider<TransactionActions>(
  TransactionActions.new,
);
