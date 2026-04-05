/// Utility for normalising phone numbers before storage and dedup comparisons.
class PhoneNormaliser {
  /// Strips spaces, hyphens, parentheses, and dots from [phone].
  /// Returns null if [phone] is null or empty after stripping.
  static String? normalise(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-().]+'), '');
    return cleaned.isEmpty ? null : cleaned;
  }
}
