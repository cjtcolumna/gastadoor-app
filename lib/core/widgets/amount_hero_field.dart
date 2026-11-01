import 'package:flutter/material.dart';

import 'money_text_field.dart';

/// The big amount at the top of the transaction form: a small "AMOUNT"
/// label and huge ₱ digits in [color], on a soft tint of the same color.
/// Same rules as [MoneyTextField]: only valid money can be typed, and it
/// must be above zero.
class AmountHeroField extends StatelessWidget {
  const AmountHeroField({
    super.key,
    required this.controller,
    required this.color,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final Color color;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final big = theme.textTheme.displaySmall?.copyWith(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      color: color,
    );
    const noBorder = InputBorder.none;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // The ₱ is its own text, not the field's prefix, so it is always
          // there, even while the amount is empty.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('₱', style: big),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: enabled,
                  autofocus: autofocus,
                  style: big,
                  cursorColor: color,
                  decoration: InputDecoration(
                    // The big number sits on the tint, with no box around it.
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: noBorder,
                    enabledBorder: noBorder,
                    focusedBorder: noBorder,
                    disabledBorder: noBorder,
                    errorBorder: noBorder,
                    focusedErrorBorder: noBorder,
                    hintText: '0.00',
                    hintStyle: big?.copyWith(
                      color: color.withValues(alpha: 0.3),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [moneyInputFormatter()],
                  validator: (value) =>
                      validateMoney(value, mustBePositive: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
