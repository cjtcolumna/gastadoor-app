import 'package:flutter/material.dart';

import '../domain/account.dart';

/// How each account type looks on screen.
extension AccountTypeUi on AccountType {
  String get label => switch (this) {
    AccountType.cash => 'Cash',
    AccountType.bank => 'Bank',
    AccountType.creditCard => 'Credit card',
    AccountType.eWallet => 'E-wallet',
    AccountType.other => 'Other',
  };

  IconData get icon => switch (this) {
    AccountType.cash => Icons.payments_outlined,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.creditCard => Icons.credit_card,
    AccountType.eWallet => Icons.phone_iphone,
    AccountType.other => Icons.wallet_outlined,
  };
}
