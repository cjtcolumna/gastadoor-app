import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/friendly_error.dart';
import '../data/budget_cycle_provider.dart';
import '../domain/budget_cycle.dart';

/// Opens the "Budget cycle" form from the Budgets screen.
Future<void> showBudgetCycleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const BudgetCycleSheet(),
  );
}

/// Choose when your budgets start over: once a month, or twice a month,
/// and on which day(s).
class BudgetCycleSheet extends ConsumerStatefulWidget {
  const BudgetCycleSheet({super.key});

  @override
  ConsumerState<BudgetCycleSheet> createState() => _BudgetCycleSheetState();
}

class _BudgetCycleSheetState extends ConsumerState<BudgetCycleSheet> {
  late BudgetCycle _cycle;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cycle = ref.read(budgetCycleProvider).value ?? BudgetCycle.calendarMonth;
  }

  void _setType(BudgetCycleType type) {
    setState(() {
      _cycle = BudgetCycle(
        type: type,
        firstDay: _cycle.firstDay,
        secondDay: type == BudgetCycleType.twiceMonthly
            ? (_cycle.secondDay ?? _suggestSecondDay(_cycle.firstDay))
            : null,
      );
    });
  }

  /// A second day that is different from the first (the 15th, or the 1st if
  /// the first is already the 15th).
  int _suggestSecondDay(int first) => first == 15 ? lastDayOfMonth : 15;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(budgetCycleProvider.notifier).save(_cycle);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Budget cycle saved.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final twice = _cycle.isTwiceMonthly;
    final second = _cycle.secondDay;
    final sameDay = twice && second == _cycle.firstDay;
    final salary = _cycle.isSalary;
    final now = DateTime.now();
    final period = salary
        ? _cycle.salaryPeriod(now, ref.watch(salaryDatesProvider).value ?? [])
        : _cycle.periodAt(now);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Budget cycle', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Your budgets start over at 0 when a new period begins. '
            'Past transactions are never deleted.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<BudgetCycleType>(
            segments: const [
              ButtonSegment(
                value: BudgetCycleType.monthly,
                label: Text('Monthly'),
              ),
              ButtonSegment(
                value: BudgetCycleType.twiceMonthly,
                label: Text('Twice a month'),
              ),
              ButtonSegment(
                value: BudgetCycleType.salary,
                label: Text('On salary'),
              ),
            ],
            selected: {_cycle.type},
            showSelectedIcon: false,
            onSelectionChanged: _saving ? null : (s) => _setType(s.first),
          ),
          const SizedBox(height: 16),
          if (!salary)
            _DayPicker(
              key: ValueKey('first-${_cycle.type}'),
              label: twice
                  ? 'First period starts on'
                  : 'A new period starts on',
              day: _cycle.firstDay,
              onChanged: _saving
                  ? null
                  : (d) => setState(
                      () => _cycle = BudgetCycle(
                        type: _cycle.type,
                        firstDay: d,
                        secondDay: _cycle.secondDay,
                      ),
                    ),
            ),
          if (twice) ...[
            const SizedBox(height: 12),
            _DayPicker(
              key: const ValueKey('second'),
              label: 'Second period starts on',
              day: second ?? _suggestSecondDay(_cycle.firstDay),
              onChanged: _saving
                  ? null
                  : (d) => setState(
                      () => _cycle = BudgetCycle(
                        type: _cycle.type,
                        firstDay: _cycle.firstDay,
                        secondDay: d,
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            sameDay
                ? 'Pick two different days.'
                : salary
                ? (period.isOpen
                      ? 'Every time you log income in your Salary category, '
                            'your budgets start over. Right now: '
                            '${periodLabel(period)}.'
                      : 'Every time you log income in your Salary category, '
                            'your budgets start over. You have not logged '
                            'a salary yet, so the calendar month '
                            '(${periodLabel(period)}) is used until you do.')
                : 'Right now: ${periodLabel(period)}. '
                      'In a short month, a late day (like the 30th) '
                      'uses the last day of that month.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: sameDay
                  ? context.appColors.expense
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.appColors.expense)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_saving || !_cycle.isValid) ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// A drop-down to pick a day of the month: 1st to 30th, or the last day.
class _DayPicker extends StatelessWidget {
  const _DayPicker({
    super.key,
    required this.label,
    required this.day,
    required this.onChanged,
  });

  final String label;
  final int day;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: day,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var d = 1; d <= lastDayOfMonth; d++)
          DropdownMenuItem(value: d, child: Text(_capitalized(dayLabel(d)))),
      ],
      onChanged: onChanged == null
          ? null
          : (d) => d == null ? null : onChanged!(d),
    );
  }

  static String _capitalized(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
