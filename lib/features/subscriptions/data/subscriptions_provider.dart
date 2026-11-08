import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/subscription.dart';
import 'subscriptions_repository.dart';

/// The signed-in user's subscriptions, soonest charge first. Screens call the
/// methods below to change them; the list reloads after each change.
///
/// Adding the expenses is not done here: the database does it every night.
final subscriptionsProvider =
    AsyncNotifierProvider<SubscriptionsNotifier, List<Subscription>>(
      SubscriptionsNotifier.new,
    );

class SubscriptionsNotifier extends AsyncNotifier<List<Subscription>> {
  SubscriptionsRepository get _repo =>
      ref.read(subscriptionsRepositoryProvider);

  @override
  Future<List<Subscription>> build() async {
    if (!ref.watch(supabaseReadyProvider)) return [];
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];
    return _repo.fetchAll();
  }

  Future<void> add({
    required String name,
    required int amountCents,
    required SubscriptionFrequency frequency,
    required DateTime firstChargeOn,
    required String accountId,
    String? categoryId,
  }) async {
    await _repo.create(
      name: name,
      amountCents: amountCents,
      frequency: frequency,
      firstChargeOn: firstChargeOn,
      accountId: accountId,
      categoryId: categoryId,
    );
    await _reload();
  }

  /// [firstChargeOn] only when the schedule changed (see the repository).
  Future<void> save(
    Subscription subscription, {
    DateTime? firstChargeOn,
  }) async {
    await _repo.update(subscription, firstChargeOn: firstChargeOn);
    await _reload();
  }

  Future<void> setActive(String id, {required bool active}) async {
    await _repo.setActive(id, active: active);
    await _reload();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    await _reload();
  }

  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
  }
}
