import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  static Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$digitsOnly?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}
