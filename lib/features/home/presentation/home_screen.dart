import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/money.dart';
import '../../transactions/data/transactions_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final spent = ref.watch(monthSpentCentsProvider);
    final monthLabel = DateFormat.yMMMM().format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('GastaDoor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent in $monthLabel',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  spent.when(
                    data: (cents) => Text(
                      Money.format(cents),
                      style: theme.textTheme.displaySmall,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                      'Could not load spending: $e',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!supabaseReady) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Supabase is not configured'),
                subtitle: Text(
                  'Copy env.example.json to env.json, add your project URL '
                  'and publishable key, then run with --dart-define-from-file=env.json.',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
