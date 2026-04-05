/// Date and time formatting utilities.
/// All timestamps are stored as unix epoch millis (integer).
class DateFormatter {
  /// Format unix epoch millis to a readable date string (e.g. "5 Apr 2026")
  static String formatDate(int epochMillis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  /// Format unix epoch millis to a readable date+time string
  static String formatDateTime(int epochMillis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${formatDate(epochMillis)} $hour:$minute';
  }

  /// Return number of days since a unix epoch millis timestamp
  static int daysSince(int epochMillis) {
    final then = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    final now = DateTime.now();
    return now.difference(then).inDays;
  }

  /// Current time as unix epoch millis
  static int nowMillis() => DateTime.now().millisecondsSinceEpoch;
}
