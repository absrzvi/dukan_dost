import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/otp_entry_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'features/onboarding/screens/shop_setup_screen.dart';
import 'features/auth/screens/phone_entry_screen.dart';

class DukaanDostApp extends ConsumerWidget {
  const DukaanDostApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'دکان دوست',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
        ),
        useMaterial3: true,
        // Large, readable text — design principle: numbers are dominant
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.textAmount,
          ),
          displayMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textAmount,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
      routes: {
        '/': (context) => const _RootRouter(),
        '/home': (context) => const HomeScreen(),
        '/onboarding': (context) => const ShopSetupScreen(),
        '/otp': (context) => OtpEntryScreen(
              phone: (ModalRoute.of(context)!.settings.arguments as String?) ??
                  '',
            ),
      },
      initialRoute: '/',
    );
  }
}

/// Root router: decides whether to show PhoneEntryScreen, ShopSetupScreen,
/// or HomeScreen based on auth + onboarding state.
class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Still resolving auth state
    if (authState.status == AuthStatus.unknown) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Not authenticated
    if (authState.status == AuthStatus.unauthenticated) {
      return const PhoneEntryScreen();
    }

    // Authenticated — check onboarding
    final shopId = authState.shopId;
    if (shopId == null) return const PhoneEntryScreen();

    return _OnboardingRouter(shopId: shopId);
  }
}

class _OnboardingRouter extends ConsumerWidget {
  final String shopId;

  const _OnboardingRouter({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check has_completed_onboarding via a FutureProvider
    final completedAsync = ref.watch(_onboardingCompletedProvider(shopId));

    return completedAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const HomeScreen(),
      data: (completed) {
        if (completed) return const HomeScreen();
        return const ShopSetupScreen();
      },
    );
  }
}

final _onboardingCompletedProvider =
    FutureProvider.family<bool, String>((ref, shopId) async {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.hasCompletedOnboarding(shopId);
});
