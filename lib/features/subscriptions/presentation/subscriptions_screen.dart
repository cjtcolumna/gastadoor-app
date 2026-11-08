import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../../core/widgets/skeleton.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../transactions/data/transaction_actions.dart';
import '../data/subscriptions_provider.dart';
import '../domain/subscription.dart';
import '../domain/subscription_totals.dart';
import 'subscription_form_sheet.dart';

/// Everything that charges you again and again, with what it costs per month.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  /// Pull down to refresh. The nightly job may have added expenses (and moved
  /// each "next charge") while the app was open.
  Future<void> _refresh(WidgetRef ref) async {
    ref.read(transactionActionsProvider).refreshScreens();
    ref.invalidate(subscriptionsProvider);
    await ref.read(subscriptionsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionsProvider);
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            tooltip: 'Add subscription',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => showSubscriptionFormSheet(context),
          ),
        ],
      ),
      body: subscriptions.when(
        data: (items) {
          final sorted = sortedByNextCharge(items);
          final active = sorted.where((s) => s.active).toList();
          final paused = sorted.where((s) => !s.active).toList();
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: screenPadding(context),
              children: [
                _CostCard(items: items),
                const SizedBox(height: 20),
                if (items.isEmpty)
                  const NoSubscriptionsCard()
                else ...[
                  if (active.isNotEmpty)
                    _SubscriptionGroup(items: active, categories: categories),
                  if (paused.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _GroupTitle('Paused'),
                    _SubscriptionGroup(items: paused, categories: categories),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () => const SkeletonPage(cards: 2),
        error: (e, _) => ErrorView(
          error: e,
          title: "Couldn't load your subscriptions",
          onRetry: () => ref.invalidate(subscriptionsProvider),
        ),
      ),
    );
  }
}

/// The big "Every month" total at the top. Subscriptions are spending, so it
/// is a soft red card with the amount in the expense red.
class _CostCard extends StatelessWidget {
  const _CostCard({required this.items});

  final List<Subscription> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final count = items.where((s) => s.active).length;

    return Card(
      color: colors.expenseSoft,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: colors.expense,
              child: const Icon(Icons.autorenew_rounded, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Every month',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Money.format(totalMonthlyCents(items)),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.expense,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'Nothing is charged right now'
                        : '${Money.format(totalYearlyCents(items))} a year · '
                              '$count active',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// A card with one row per subscription.
class _SubscriptionGroup extends StatelessWidget {
  const _SubscriptionGroup({required this.items, required this.categories});

  final List<Subscription> items;
  final Map<String, Category> categories;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, s) in items.indexed) ...[
            if (i > 0) const Divider(height: 1),
            SubscriptionTile(
              subscription: s,
              category: categories[s.categoryId],
              onTap: () => showSubscriptionFormSheet(context, existing: s),
            ),
          ],
        ],
      ),
    );
  }
}

/// One subscription: its category icon, name, when it charges next, and the
/// price. A paused one is faded and says "Paused".
class SubscriptionTile extends StatelessWidget {
  const SubscriptionTile({
    super.key,
    required this.subscription,
    required this.category,
    required this.onTap,
  });

  final Subscription subscription;

  /// The subscription's category, or null when it has none.
  final Category? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = subscription;
    final category = this.category;

    return Opacity(
      opacity: s.active ? 1 : 0.55,
      child: ListTile(
        onTap: onTap,
        leading: category != null
            ? CategoryAvatar(icon: category.icon, color: category.color)
            : CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                foregroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.autorenew_rounded),
              ),
        title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(s.active ? nextChargeText(s) : 'Paused'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              Money.format(s.amountCents),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              frequencyUnit(s.frequency),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when there are no subscriptions yet, with a button to add the first.
class NoSubscriptionsCard extends StatelessWidget {
  const NoSubscriptionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.autorenew_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pay for Spotify, Netflix or anything else that repeats? Add it '
              'here to see what it costs each month. GastaDoor adds each '
              'charge as an expense on the day it is due.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => showSubscriptionFormSheet(context),
              child: const Text('Add subscription'),
            ),
          ],
        ),
      ),
    );
  }
}
