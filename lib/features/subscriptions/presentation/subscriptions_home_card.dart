import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/subscriptions_provider.dart';
import '../domain/subscription.dart';
import '../domain/subscription_totals.dart';
import 'subscriptions_screen.dart';

/// The "Subscriptions" section on Home: a Manage link, then which
/// subscription charges next.
class SubscriptionsHomeSection extends ConsumerWidget {
  const SubscriptionsHomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subscriptions = ref.watch(subscriptionsProvider);
    final items = subscriptions.value ?? const <Subscription>[];
    final next = nextUp(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Subscriptions',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/subscriptions'),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (!subscriptions.hasValue && subscriptions.hasError)
          ErrorView.inline(
            error: subscriptions.error!,
            title: "Couldn't load your subscriptions",
            onRetry: () => ref.invalidate(subscriptionsProvider),
          )
        else if (!subscriptions.hasValue)
          const SkeletonListCard(rows: 1)
        else if (items.isEmpty)
          const NoSubscriptionsCard()
        else if (next == null)
          const Card(
            child: ListTile(
              leading: Icon(Icons.pause_circle_outline_rounded),
              title: Text('All paused'),
              subtitle: Text('Nothing is being charged right now'),
            ),
          )
        else
          _NextUpCard(subscription: next),
      ],
    );
  }
}

/// A tappable card with the subscription that charges next.
class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.go('/subscriptions'),
        // Subscriptions are spending: soft red with the expense red.
        leading: CircleAvatar(
          backgroundColor: colors.expenseSoft,
          foregroundColor: colors.expense,
          child: const Icon(Icons.autorenew_rounded),
        ),
        title: Text(
          'Next: ${subscription.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(nextChargeText(subscription)),
        trailing: Text(
          Money.format(subscription.amountCents),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.expense,
          ),
        ),
      ),
    );
  }
}
