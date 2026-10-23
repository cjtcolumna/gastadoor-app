import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../domain/budget.dart';

/// All Supabase calls for the `budgets` table.
/// Row Level Security keeps each user to their own budgets.
class BudgetsRepository {
  BudgetsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Budget>> fetchAll() async {
    final rows = await _client.from('budgets').select().order('created_at');
    return rows.map(Budget.fromJson).toList();
  }

  /// A monthly budget. [categoryId] null means "all spending".
  Future<void> create({
    required String? categoryId,
    required String name,
    required int amountCents,
  }) async {
    await _client.from('budgets').insert({
      'category_id': categoryId,
      'name': name,
      'period': 'monthly',
      'amount_cents': amountCents,
    });
  }

  Future<void> update(Budget budget) async {
    await _client
        .from('budgets')
        .update({
          'category_id': budget.categoryId,
          'name': budget.name,
          'amount_cents': budget.amountCents,
        })
        .eq('id', budget.id);
  }

  Future<void> delete(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }
}

final budgetsRepositoryProvider = Provider<BudgetsRepository>(
  (ref) => BudgetsRepository(ref.watch(supabaseClientProvider)),
);
