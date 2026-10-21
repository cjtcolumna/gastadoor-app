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
    this.mustBePositive = false,
    this.enabled = true,
    this.autofocus = false,
    this.large = false,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final bool allowNegative;

  /// When false, an empty box means zero.
  final bool required;

  /// When true, zero is not allowed (e.g. an expense of ₱0.00).
  final bool mustBePositive;
  final bool enabled;
  final bool autofocus;

  /// Big digits, for the main amount on a form.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final bigText = Theme.of(context).textTheme.headlineMedium
        ?.copyWith(fontWeight: FontWeight.w600);

    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      style: large ? bigText : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixText: '₱ ',
        prefixStyle: large ? bigText : null,
        hintText: '0.00',
      ),
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: allowNegative,
      ),
      inputFormatters: [moneyInputFormatter(allowNegative: allowNegative)],
      validator: (value) => validateMoney(
        value,
        required: required,
        mustBePositive: mustBePositive,
      ),
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

String? validateMoney(
  String? value, {
  bool required = true,
  bool mustBePositive = false,
}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? 'Enter an amount' : null;
  final cents = Money.parseToCents(text);
  if (cents == null) return 'Enter a valid amount';
  if (mustBePositive && cents <= 0) return 'Enter an amount above zero';
  return null;
}
