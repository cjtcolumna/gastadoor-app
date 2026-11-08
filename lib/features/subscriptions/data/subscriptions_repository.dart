import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/dates.dart';
import '../domain/subscription.dart';

/// All Supabase calls for the `subscriptions` table.
/// Row Level Security keeps each user to their own rows, and the database
/// fills in `user_id` and `next_charge_on` for us.
class SubscriptionsRepository {
  SubscriptionsRepository(this._client);

  final SupabaseClient _client;

  /// The soonest charge first.
  Future<List<Subscription>> fetchAll() async {
    final rows = await _client
        .from('subscriptions')
        .select()
        .order('next_charge_on')
        .order('name');
    return rows.map(Subscription.fromJson).toList();
  }

  Future<void> create({
    required String name,
    required int amountCents,
    required SubscriptionFrequency frequency,
    required DateTime firstChargeOn,
    required String accountId,
    String? categoryId,
  }) async {
    await _client.from('subscriptions').insert({
      'name': name.trim(),
      'amount_cents': amountCents,
      'frequency': frequency.name,
      'first_charge_on': toDbDate(firstChargeOn),
      'account_id': accountId,
      'category_id': categoryId,
    });
  }

  /// Saves the details. Pass [firstChargeOn] only when the next charge date
  /// or monthly/yearly changed: the database then works out the new next
  /// charge. Left null, the schedule is not touched. (Sending the same date
  /// again would move a "31st" subscription to the 28th for good.)
  Future<void> update(Subscription s, {DateTime? firstChargeOn}) async {
    await _client
        .from('subscriptions')
        .update({
          'name': s.name.trim(),
          'amount_cents': s.amountCents,
          'frequency': s.frequency.name,
          'account_id': s.accountId,
          'category_id': s.categoryId,
          if (firstChargeOn != null) 'first_charge_on': toDbDate(firstChargeOn),
        })
        .eq('id', s.id);
  }

  Future<void> setActive(String id, {required bool active}) async {
    await _client.from('subscriptions').update({'active': active}).eq('id', id);
  }

  /// Deletes the subscription. Expenses it already made stay in History.
  Future<void> delete(String id) async {
    await _client.from('subscriptions').delete().eq('id', id);
  }
}

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>(
  (ref) => SubscriptionsRepository(ref.watch(supabaseClientProvider)),
);
