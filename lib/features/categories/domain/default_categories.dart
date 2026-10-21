import '../../transactions/domain/transaction.dart';

/// A starter category every user gets.
/// [icon] and [color] are names from `category_visuals.dart`.
typedef DefaultCategory = ({
  String name,
  TransactionKind kind,
  String icon,
  String color,
});

const defaultCategories = <DefaultCategory>[
  (
    name: 'Food',
    kind: TransactionKind.expense,
    icon: 'restaurant',
    color: 'orange',
  ),
  (
    name: 'Transport',
    kind: TransactionKind.expense,
    icon: 'bus',
    color: 'blue',
  ),
  (
    name: 'Bills',
    kind: TransactionKind.expense,
    icon: 'receipt',
    color: 'amber',
  ),
  (
    name: 'Shopping',
    kind: TransactionKind.expense,
    icon: 'shopping',
    color: 'pink',
  ),
  (name: 'Health', kind: TransactionKind.expense, icon: 'health', color: 'red'),
  (
    name: 'Fun',
    kind: TransactionKind.expense,
    icon: 'celebration',
    color: 'purple',
  ),
  (
    name: 'Other',
    kind: TransactionKind.expense,
    icon: 'category',
    color: 'grey',
  ),
  (name: 'Salary', kind: TransactionKind.income, icon: 'work', color: 'green'),
  (name: 'Gift', kind: TransactionKind.income, icon: 'gift', color: 'teal'),
  (
    name: 'Other',
    kind: TransactionKind.income,
    icon: 'savings',
    color: 'indigo',
  ),
];
