import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/supabase/supabase_providers.dart';
import 'package:gastadoor/features/budgets/data/budget_cycle_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget_cycle.dart';
import 'package:gastadoor/features/transactions/data/transaction_actions.dart';
import 'package:gastadoor/features/transactions/data/transactions_repository.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:gastadoor/features/transactions/domain/transaction_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

const jade = User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'jade@example.com',
  createdAt: '2026-10-21T08:00:00Z',
);

/// Counts how often transactions are loaded, and for which days.
class FakeTransactionsRepository implements TransactionsRepository {
  final ranges = <(DateTime, DateTime)>[];

  @override
  Future<List<Transaction>> fetchBetween(DateTime from, DateTime to) async {
    ranges.add((from, to));
    return const [];
  }

  @override
  Future<void> create(TransactionDraft draft) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixedCycle extends BudgetCycleNotifier {
  FixedCycle(this.cycle);

  final BudgetCycle cycle;

  @override
  Future<BudgetCycle> build() async => cycle;
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  late FakeTransactionsRepository repo;
  late List<DateTime> salaryDates;

  ProviderContainer containerFor(BudgetCycle cycle) {
    repo = FakeTransactionsRepository();
    final container = ProviderContainer(
      overrides: [
        supabaseReadyProvider.overrideWithValue(true),
        currentUserProvider.overrideWith((ref) => Stream.value(jade)),
        transactionsRepositoryProvider.overrideWithValue(repo),
        budgetCycleProvider.overrideWith(() => FixedCycle(cycle)),
        salaryDatesProvider.overrideWith((ref) async => [...salaryDates]),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final draft = TransactionDraft(
    kind: TransactionKind.income,
    amountCents: 2500000,
    accountId: 'a',
    occurredOn: today,
  );

  setUp(() => salaryDates = []);

  test('Home and budgets load the current period, not a fixed month', () async {
    final container = containerFor(
      const BudgetCycle(
        type: BudgetCycleType.twiceMonthly,
        firstDay: 1,
        secondDay: 16,
      ),
    );
    final period = await container.read(currentPeriodProvider.future);
    await container.read(monthTransactionsProvider.future);

    expect(repo.ranges.single, (period.start, period.end));
  });

  test('saving a transaction reloads the current period', () async {
    final container = containerFor(BudgetCycle.calendarMonth);
    await container.read(monthTransactionsProvider.future);
    expect(repo.ranges, hasLength(1));

    await container.read(transactionActionsProvider).add(draft);
    await container.read(monthTransactionsProvider.future);
    expect(repo.ranges, hasLength(2));
  });

  test('salary cycle: before any salary it is the calendar month', () async {
    final container = containerFor(
      const BudgetCycle(type: BudgetCycleType.salary),
    );
    final period = await container.read(currentPeriodProvider.future);
    expect(period.start, DateTime(today.year, today.month, 1));
    expect(period.isOpen, isFalse);
  });

  test('salary cycle: the period starts on the latest salary', () async {
    salaryDates = [daysAgo(10)];
    final container = containerFor(
      const BudgetCycle(type: BudgetCycleType.salary),
    );

    final period = await container.read(currentPeriodProvider.future);
    expect(period.start, daysAgo(10));
    expect(period.end, today);
    expect(period.isOpen, isTrue);

    await container.read(monthTransactionsProvider.future);
    expect(repo.ranges.single, (daysAgo(10), today));
  });

  test('salary cycle: logging a salary resets the period right away', () async {
    salaryDates = [daysAgo(10)];
    final container = containerFor(
      const BudgetCycle(type: BudgetCycleType.salary),
    );
    await container.read(monthTransactionsProvider.future);

    // The new salary is saved: the app asks for the salary dates again.
    salaryDates = [today, daysAgo(10)];
    await container.read(transactionActionsProvider).add(draft);

    final period = await container.read(currentPeriodProvider.future);
    expect(period.start, today);
    await container.read(monthTransactionsProvider.future);
    expect(repo.ranges.last, (today, today));
  });
}
