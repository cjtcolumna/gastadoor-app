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

  /// Parses user input like "1,234.50" into cents. Returns null if invalid.
  static int? parseToCents(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    final match = RegExp(r'^(-?)(\d*)(?:\.(\d{0,2}))?$').firstMatch(cleaned);
    if (match == null) return null;
    final sign = match.group(1) == '-' ? -1 : 1;
    final whole = int.tryParse(match.group(2)!.isEmpty ? '0' : match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    if (whole == null) return null;
    return sign * (whole * 100 + int.parse(fraction));
  }
}
