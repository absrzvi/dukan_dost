import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  static Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return false;
    // Normalise Pakistani numbers: 03xx... → 923xx...
    String normalised = digitsOnly;
    if (normalised.startsWith('0') && normalised.length == 11) {
      normalised = '92${normalised.substring(1)}';
    }
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$normalised?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}
