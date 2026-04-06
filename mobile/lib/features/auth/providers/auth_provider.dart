import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../repositories/auth_repository.dart';
import '../../../core/network/api_client.dart';

// Secure storage provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});

// Auth state
enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? token;
  final String? shopId;
  final bool isNewShop;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.token,
    this.shopId,
    this.isNewShop = false,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    String? shopId,
    bool? isNewShop,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      shopId: shopId ?? this.shopId,
      isNewShop: isNewShop ?? this.isNewShop,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Check persisted auth on startup so the spinner resolves immediately.
    Future.microtask(checkAuthStatus);
    return const AuthState();
  }

  Future<void> checkAuthStatus() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'session_token');
    final shopId = await storage.read(key: 'shop_id');

    if (token != null && shopId != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        token: token,
        shopId: shopId,
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> requestOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.requestOtp(phone);
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.verifyOtp(phone, otp);

      // Store token securely
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: 'session_token', value: result.token);
      await storage.write(key: 'shop_id', value: result.shopId);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        token: result.token,
        shopId: result.shopId,
        isNewShop: result.isNewShop,
        isLoading: false,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.deleteAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
