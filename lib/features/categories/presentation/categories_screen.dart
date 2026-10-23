import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../../core/widgets/skeleton.dart';
import '../../transactions/domain/transaction.dart';
import '../data/categories_repository.dart';
import '../domain/category.dart';
import 'category_form_sheet.dart';
import 'category_visuals.dart';

/// Lists expense and income categories. Tap one to edit it, or + to add.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => showCategoryFormSheet(context),
          ),
        ],
      ),
      body: categories.when(
        data: (list) => ListView(
          padding: screenPadding(context),
          children: [
            _Section(
              title: 'Expenses',
              kind: TransactionKind.expense,
              categories: list
                  .where((c) => c.kind == TransactionKind.expense)
                  .toList(),
            ),
            const SizedBox(height: 20),
            _Section(
              title: 'Income',
              kind: TransactionKind.income,
              categories: list
                  .where((c) => c.kind == TransactionKind.income)
                  .toList(),
            ),
            const _ArchivedSection(),
          ],
        ),
        loading: () => const SkeletonPage(),
        error: (e, _) => ErrorView(
          error: e,
          title: "Couldn't load your categories",
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
      ),
    );
  }
}

/// A heading ("Expenses") with an add link, then a card of categories.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.kind,
    required this.categories,
  });

  final String title;
  final TransactionKind kind;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
            ),
            TextButton.icon(
              onPressed: () => showCategoryFormSheet(context, kind: kind),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: categories.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('None yet.'),
                )
              : Column(
                  children: [
                    for (final (i, c) in categories.indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: CategoryAvatar(icon: c.icon, color: c.color),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            showCategoryFormSheet(context, existing: c),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// "Archived (2)": closed by default, each row has a Restore button.
class _ArchivedSection extends ConsumerStatefulWidget {
  const _ArchivedSection();

  @override
  ConsumerState<_ArchivedSection> createState() => _ArchivedSectionState();
}

class _ArchivedSectionState extends ConsumerState<_ArchivedSection> {
  bool _open = false;
  final _restoring = <String>{};

  Future<void> _restore(Category c) async {
    setState(() => _restoring.add(c.id));
    try {
      await ref.read(categoryActionsProvider).restore(c.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(categorySaveError(e, c.name))));
      }
    }
    if (mounted) setState(() => _restoring.remove(c.id));
  }

  @override
  Widget build(BuildContext context) {
    final archived = ref.watch(archivedCategoriesProvider).value ?? const [];
    if (archived.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.inventory_2_rounded),
          title: Text('Archived (${archived.length})'),
          subtitle: const Text('Hidden when adding expenses and budgets'),
          trailing: AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more_rounded),
          ),
          onExpansionChanged: (open) => setState(() => _open = open),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            for (final c in archived) ...[
              const Divider(height: 1),
              ListTile(
                leading: CategoryAvatar(icon: c.icon, color: c.color),
                title: Text(c.name),
                subtitle: Text(
                  c.kind == TransactionKind.income ? 'Income' : 'Expense',
                ),
                trailing: _restoring.contains(c.id)
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : TextButton(
                        onPressed: () => _restore(c),
                        child: const Text('Restore'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
