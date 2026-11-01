import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/domain/transaction.dart';
import '../data/categories_repository.dart';
import '../domain/category.dart';
import 'category_visuals.dart';

/// "Archived (2)": closed by default, each row has a Restore button.
/// Shows only the archived categories of one [kind] (the side of the Budget
/// page you are looking at), and nothing at all when there are none.
class ArchivedCategoriesSection extends ConsumerStatefulWidget {
  const ArchivedCategoriesSection({super.key, required this.kind});

  final TransactionKind kind;

  @override
  ConsumerState<ArchivedCategoriesSection> createState() =>
      _ArchivedCategoriesSectionState();
}

class _ArchivedCategoriesSectionState
    extends ConsumerState<ArchivedCategoriesSection> {
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
    final archived = (ref.watch(archivedCategoriesProvider).value ?? const [])
        .where((c) => c.kind == widget.kind)
        .toList();
    if (archived.isEmpty) return const SizedBox.shrink();

    final isIncome = widget.kind == TransactionKind.income;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.inventory_2_rounded),
          title: Text('Archived (${archived.length})'),
          subtitle: Text(
            isIncome
                ? 'Hidden when adding income'
                : 'Hidden when adding expenses, and their limits are paused',
          ),
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
