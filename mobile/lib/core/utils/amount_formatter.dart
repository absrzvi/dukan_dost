// Utility functions for PKR paisa formatting
// Iron Rule: All amounts are integer paisa. Never use double/float for money.

class AmountFormatter {
  /// Format paisa as PKR display string
  /// e.g. 150000 paisa → "PKR 1,500"
  static String format(int paisa) {
    final rupees = paisa ~/ 100;
    final paisaRemainder = paisa % 100;

    if (paisaRemainder == 0) {
      return 'PKR ${_formatWithCommas(rupees)}';
    }
    return 'PKR ${_formatWithCommas(rupees)}.${paisaRemainder.toString().padLeft(2, '0')}';
  }

  /// Format paisa as plain number string (no PKR prefix)
  static String formatPlain(int paisa) {
    final rupees = paisa ~/ 100;
    return _formatWithCommas(rupees);
  }

  /// Parse PKR amount string to paisa integer
  /// e.g. "1500" → 150000 paisa
  static int parseToPaisa(String rupeesString) {
    final cleaned = rupeesString.replaceAll(',', '').replaceAll('PKR ', '').trim();
    final rupees = int.parse(cleaned);
    return rupees * 100;
  }

  static String _formatWithCommas(int amount) {
    final str = amount.toString();
    if (str.length <= 3) return str;

    final result = StringBuffer();
    final mod = str.length % 3;

    for (int i = 0; i < str.length; i++) {
      if (i != 0 && (i - mod) % 3 == 0) result.write(',');
      result.write(str[i]);
    }
    return result.toString();
  }
}
