import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/money.dart';

/// A ₱ amount box. It only lets you type numbers with up to 2 decimals,
/// and the parent reads the value in cents with [Money.parseToCents].
class MoneyTextField extends StatelessWidget {
  const MoneyTextField({
    super.key,
    required this.controller,
    this.label = 'Amount',
    this.helperText,
    this.allowNegative = false,
    this.required = true,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final bool allowNegative;

  /// When false, an empty box means zero.
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixText: '₱ ',
        hintText: '0.00',
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: allowNegative,
      ),
      inputFormatters: [moneyInputFormatter(allowNegative: allowNegative)],
      validator: (value) => validateMoney(value, required: required),
    );
  }
}

/// Blocks any keystroke that would not make a valid amount so far,
/// e.g. letters, two dots, or a third decimal place.
TextInputFormatter moneyInputFormatter({bool allowNegative = false}) {
  final pattern = RegExp(
    allowNegative ? r'^-?[\d,]*\.?\d{0,2}$' : r'^[\d,]*\.?\d{0,2}$',
  );
  return TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        pattern.hasMatch(newValue.text) ? newValue : oldValue,
  );
}

String? validateMoney(String? value, {bool required = true}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? 'Enter an amount' : null;
  if (Money.parseToCents(text) == null) return 'Enter a valid amount';
  return null;
}
