import 'package:intl/intl.dart';

/// Money is always stored as an integer number of cents (centavos).
/// Convert to a display string only at the edges of the app.
class Money {
  const Money._();

  static const defaultCurrency = 'PHP';

  static String format(int cents, {String currency = defaultCurrency}) {
    final formatter = NumberFormat.simpleCurrency(name: currency);
    return formatter.format(cents / 100);
  }

  /// A short amount for chart axes, e.g. 2500000 cents -> "₱25K".
  static String formatCompact(int cents, {String currency = defaultCurrency}) {
    final formatter = NumberFormat.compactSimpleCurrency(
      name: currency,
      decimalDigits: 0,
    );
    return formatter.format(cents / 100);
  }

  /// A very short amount that fits in a tiny pill: at most 3 digits, with
  /// k or m for thousands and millions. 85000 -> "₱850", 150000 -> "₱1.5k",
  /// 1050000 -> "₱10.5k", 10500000 -> "₱105k", 120000000 -> "₱1.2m".
  ///
  /// Cents are cut off, never rounded up, so a short amount never looks
  /// bigger than the real one. Negative amounts show as ₱0. Whole-number
  /// math only, so there are no rounding surprises.
  static String formatShort(int cents, {String symbol = '₱'}) {
    final pesos = (cents < 0 ? 0 : cents) ~/ 100;
    if (pesos < 1000) return '$symbol$pesos';

    final (unit, suffix) = pesos >= 1000000 ? (1000000, 'm') : (1000, 'k');
    final whole = pesos ~/ unit;
    // Keep 3 digits in total: "1.5k" and "10.5k" have one decimal or
    // fewer, "1.05k" has two, "105k" has none.
    final decimals = (3 - whole.toString().length).clamp(0, 2);
    var fraction = '';
    if (decimals > 0) {
      var scale = 1;
      for (var i = 0; i < decimals; i++) {
        scale *= 10;
      }
      fraction = ((pesos % unit) * scale ~/ unit).toString().padLeft(
        decimals,
        '0',
      );
      fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    }
    return '$symbol$whole${fraction.isEmpty ? '' : '.$fraction'}$suffix';
  }

  /// Turns cents into plain text for an input box, e.g. 123450 -> "1234.50".
  /// Uses whole-number math only, so there are no rounding surprises.
  static String toInputText(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final fraction = (abs % 100).toString().padLeft(2, '0');
    return '$sign${abs ~/ 100}.$fraction';
  }

  /// Parses user input like "1,234.50" into cents. Returns null if invalid.
  static int? parseToCents(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    final match = RegExp(r'^(-?)(\d*)(?:\.(\d{0,2}))?$').firstMatch(cleaned);
    if (match == null) return null;
    // "-", "." or "-." have no digits at all, so they are not an amount.
    if (match.group(2)!.isEmpty && (match.group(3) ?? '').isEmpty) return null;
    final sign = match.group(1) == '-' ? -1 : 1;
    final whole = int.tryParse(match.group(2)!.isEmpty ? '0' : match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    if (whole == null) return null;
    return sign * (whole * 100 + int.parse(fraction));
  }
}
