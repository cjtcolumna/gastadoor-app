import '../../transactions/domain/transaction.dart';

/// A starter category every user gets: name, expense/income, and an emoji.
typedef DefaultCategory = ({String name, TransactionKind kind, String icon});

const defaultCategories = <DefaultCategory>[
  (name: 'Food', kind: TransactionKind.expense, icon: '🍔'),
  (name: 'Transport', kind: TransactionKind.expense, icon: '🚌'),
  (name: 'Bills', kind: TransactionKind.expense, icon: '💡'),
  (name: 'Shopping', kind: TransactionKind.expense, icon: '🛍️'),
  (name: 'Health', kind: TransactionKind.expense, icon: '💊'),
  (name: 'Fun', kind: TransactionKind.expense, icon: '🎉'),
  (name: 'Other', kind: TransactionKind.expense, icon: '📦'),
  (name: 'Salary', kind: TransactionKind.income, icon: '💼'),
  (name: 'Gift', kind: TransactionKind.income, icon: '🎁'),
  (name: 'Other', kind: TransactionKind.income, icon: '💰'),
];

/// Emoji shown for a category that has no icon saved.
const fallbackCategoryIcon = '🏷️';
