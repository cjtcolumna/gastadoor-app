import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../domain/account.dart';

/// All Supabase calls for the `accounts` table.
/// Row Level Security makes sure each user only touches their own rows,
/// and the database fills in `user_id` for us.
class AccountsRepository {
  AccountsRepository(this._client);

  final SupabaseClient _client;

  /// Accounts that are not archived, oldest first.
  Future<List<Account>> fetchActive() async {
    final rows = await _client
        .from('accounts')
        .select()
        .eq('archived', false)
        .order('created_at');
    return rows.map(Account.fromJson).toList();
  }

  /// Current balance of each account in cents, keyed by account id.
  /// Read from the `account_balances` view, which adds up transactions.
  Future<Map<String, int>> fetchBalances() async {
    final rows = await _client
        .from('account_balances')
        .select('account_id, balance_cents');
    return {
      for (final row in rows)
        row['account_id'] as String: (row['balance_cents'] as num).toInt(),
    };
  }

  /// True if the user has ever made an account (archived ones count too).
  Future<bool> hasAny() async {
    final rows = await _client.from('accounts').select('id').limit(1);
    return rows.isNotEmpty;
  }

  Future<void> create({
    required String name,
    required AccountType type,
    int openingBalanceCents = 0,
    String? parentId,
  }) async {
    await _client.from('accounts').insert({
      'name': name.trim(),
      'type': type.dbValue,
      'opening_balance_cents': openingBalanceCents,
      'parent_id': parentId,
    });
  }

  Future<void> update(Account account) async {
    await _client
        .from('accounts')
        .update({
          'name': account.name.trim(),
          'type': account.type.dbValue,
          'opening_balance_cents': account.openingBalanceCents,
          'parent_id': account.parentId,
        })
        .eq('id', account.id);
    // Pockets always match their parent's type (GoTyme is a bank, so
    // Travel is too).
    await _client
        .from('accounts')
        .update({'type': account.type.dbValue})
        .eq('parent_id', account.id);
  }

  /// Archived accounts, most recently changed first.
  Future<List<Account>> fetchArchived() async {
    final rows = await _client
        .from('accounts')
        .select()
        .eq('archived', true)
        .order('updated_at', ascending: false);
    return rows.map(Account.fromJson).toList();
  }

  /// Hides the account (and its pockets) but keeps their history.
  Future<void> archive(String id) async {
    await _client
        .from('accounts')
        .update({'archived': true})
        .or('id.eq.$id,parent_id.eq.$id');
  }

  /// Brings an archived account back, with its pockets.
  /// Restoring a pocket also restores its parent, so it has a home.
  Future<void> restore(Account account) async {
    final parentId = account.parentId;
    await _client
        .from('accounts')
        .update({'archived': false})
        .or(
          parentId == null
              ? 'id.eq.${account.id},parent_id.eq.${account.id}'
              : 'id.eq.${account.id},id.eq.$parentId',
        );
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(supabaseClientProvider)),
);
