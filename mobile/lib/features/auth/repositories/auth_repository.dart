import 'package:dio/dio.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  /// Request OTP for phone number.
  /// Returns true on success.
  /// Throws [AuthException] on failure.
  Future<bool> requestOtp(String phone) async {
    try {
      final response = await _dio.post('/api/auth/otp/request/', data: {'phone': phone});
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const AuthException('بہت زیادہ کوشش۔ کچھ دیر بعد دوبارہ کریں۔');
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw const AuthException('انٹرنیٹ کنیکشن نہیں ہے');
      }
      throw const AuthException('OTP بھیجنے میں مسئلہ ہوا');
    }
  }

  /// Verify OTP. Returns [AuthResult] with token and shop info.
  Future<AuthResult> verifyOtp(String phone, String otp) async {
    try {
      final response = await _dio.post('/api/auth/otp/verify/', data: {
        'phone': phone,
        'otp': otp,
      });
      final data = response.data as Map<String, dynamic>;
      return AuthResult(
        token: data['token'] as String,
        shopId: data['shop_id'] as String,
        isNewShop: data['is_new_shop'] as bool,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('غلط یا میعاد ختم کوڈ');
      }
      throw const AuthException('تصدیق میں مسئلہ ہوا');
    }
  }
}

class AuthResult {
  final String token;
  final String shopId;
  final bool isNewShop;

  const AuthResult({
    required this.token,
    required this.shopId,
    required this.isNewShop,
  });
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
