import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/utils/friendly_error.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/category.dart';
import '../domain/default_categories.dart';

/// All Supabase calls for the `categories` table.
class CategoriesRepository {
  CategoriesRepository(this._client);

  final SupabaseClient _client;

  /// Categories that are not archived, sorted by name.
  Future<List<Category>> fetchActive() => _fetch(archived: false);

  /// Archived categories, sorted by name.
  Future<List<Category>> fetchArchived() => _fetch(archived: true);

  Future<List<Category>> _fetch({required bool archived}) async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('archived', archived)
        .order('name');
    return rows.map(Category.fromJson).toList();
  }

  /// Gives a brand-new user the starter categories. Does nothing if they
  /// already have any (including archived ones), so renaming or archiving
  /// a starter category doesn't make it come back.
  Future<void> addStartersIfNew(String userId) async {
    final existing = await _client.from('categories').select('id').limit(1);
    if (existing.isNotEmpty) return;
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
          // If two screens do this at the same moment, skip duplicates.
          onConflict: 'user_id,kind,name',
          ignoreDuplicates: true,
        );
  }

  Future<void> create({
    required String name,
    required TransactionKind kind,
    required String icon,
    required String color,
  }) async {
    await _client.from('categories').insert({
      'name': name.trim(),
      'kind': kind.name,
      'icon': icon,
      'color': color,
    });
  }

  /// Changes name, icon, and color. The kind (expense/income) never changes,
  /// so old transactions always stay in a matching category.
  Future<void> update(Category category) async {
    await _client
        .from('categories')
        .update({
          'name': category.name.trim(),
          'icon': category.icon,
          'color': category.color,
        })
        .eq('id', category.id);
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    await _client
        .from('categories')
        .update({'archived': archived})
        .eq('id', id);
  }
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's active categories (both expense and income).
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  if (!ref.watch(supabaseReadyProvider)) return [];
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  final repo = ref.watch(categoriesRepositoryProvider);
  await repo.addStartersIfNew(user.id);
  return repo.fetchActive();
});

/// Categories the user archived (shown in the Archived section).
final archivedCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  if (!ref.watch(supabaseReadyProvider)) return [];
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(categoriesRepositoryProvider).fetchArchived();
});

/// Add, edit, archive, or restore a category, then refresh everything
/// that shows category names and icons.
class CategoryActions {
  CategoryActions(this._ref);

  final Ref _ref;

  CategoriesRepository get _repo => _ref.read(categoriesRepositoryProvider);

  Future<void> add({
    required String name,
    required TransactionKind kind,
    required String icon,
    required String color,
  }) async {
    await _repo.create(name: name, kind: kind, icon: icon, color: color);
    _refresh();
  }

  Future<void> save(Category category) async {
    await _repo.update(category);
    _refresh();
  }

  Future<void> archive(String id) async {
    await _repo.setArchived(id, archived: true);
    _refresh();
  }

  Future<void> restore(String id) async {
    await _repo.setArchived(id, archived: false);
    _refresh();
  }

  void _refresh() {
    _ref.invalidate(categoriesProvider);
    _ref.invalidate(archivedCategoriesProvider);
    // History rows show category names and icons.
    _ref.invalidate(historyPageProvider);
  }
}

final categoryActionsProvider = Provider<CategoryActions>(CategoryActions.new);

/// A friendly message for a failed save. Postgres error 23505 means
/// "that would make a duplicate": here, two categories with the same name.
String categorySaveError(Object error, String name) {
  if (error is PostgrestException && error.code == '23505') {
    return 'You already have a category called "${name.trim()}" '
        '(it may be archived).';
  }
  return friendlyError(error);
}
