import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../domain/category.dart';
import '../domain/default_categories.dart';

/// All Supabase calls for the `categories` table.
class CategoriesRepository {
  CategoriesRepository(this._client);

  final SupabaseClient _client;

  /// Categories that are not archived, sorted by name.
  Future<List<Category>> fetchActive() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('archived', false)
        .order('name');
    return rows.map(Category.fromJson).toList();
  }

  /// Adds any starter category the user doesn't have yet.
  /// "ignoreDuplicates" skips names that already exist, so this is safe
  /// to run every time.
  Future<void> ensureDefaults(String userId) async {
    await _client
        .from('categories')
        .upsert(
          [
            for (final c in defaultCategories)
              {
                'user_id': userId,
                'name': c.name,
                'kind': c.kind.name,
                'icon': c.icon,
                'color': c.color,
              },
          ],
          onConflict: 'user_id,kind,name',
          ignoreDuplicates: true,
        );
  }
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's categories (both expense and income).
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  if (!ref.watch(supabaseReadyProvider)) return [];
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  final repo = ref.watch(categoriesRepositoryProvider);
  await repo.ensureDefaults(user.id);
  return repo.fetchActive();
});
