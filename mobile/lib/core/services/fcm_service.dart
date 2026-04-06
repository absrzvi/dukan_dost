import 'package:flutter/foundation.dart';

/// Handles FCM token registration with the backend.
///
/// TODO STORY-016: Add firebase_messaging dependency and implement real FCM
/// registration using FirebaseMessaging.instance.getToken().
class FCMService {
  /// Registers [fcmToken] for [deviceId] with the backend.
  /// Currently a stub that logs the token; real Firebase integration pending.
  static Future<void> registerToken({
    required String authToken,
    required String deviceId,
    String? fcmToken,
  }) async {
    // TODO STORY-016: Call POST /api/shop/devices/register-fcm/ with real token.
    debugPrint('[FCM] Would register token: $fcmToken for device: $deviceId');
  }
}
