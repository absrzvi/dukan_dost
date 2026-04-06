import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/env.dart';

// Module-level instance — created once, not per-request
const _secureStorage = FlutterSecureStorage();

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Auth interceptor — attaches session token to every request
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _secureStorage.read(key: 'session_token');
      if (token != null) {
        options.headers['Authorization'] = 'Token $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      // 401 — token expired, trigger logout (handled in auth provider)
      handler.next(error);
    },
  ));

  return dio;
});
