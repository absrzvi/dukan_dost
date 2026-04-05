import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import 'contact_import_screen.dart';

class ShopSetupScreen extends ConsumerStatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  ConsumerState<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends ConsumerState<ShopSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _localityController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(shopSetupProvider.notifier);
    if (!notifier.canSubmit) return;

    final shopId = ref.read(authProvider).shopId ?? '';
    final name = _nameController.text.trim();
    final locality = _localityController.text.trim();

    // Update local state to submitting
    notifier.setName(name);
    notifier.setLocality(locality);

    // Write to local DB first, then fire network call async (do NOT await for navigation)
    final repo = ref.read(shopRepositoryProvider);
    unawaited(
      repo.updateShopProfile(
        shopId: shopId,
        name: name,
        locality: locality.isEmpty ? null : locality,
      ),
    );

    // Navigate immediately — offline-first
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ContactImportScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(shopSetupProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Text(
                  AppStrings.shopName,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اپنی دکان کی تفصیل درج کریں',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // Shop name field
                TextFormField(
                  key: const Key('shopNameField'),
                  controller: _nameController,
                  textDirection: TextDirection.rtl,
                  maxLength: 255,
                  onChanged: (v) => ref.read(shopSetupProvider.notifier).setName(v),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'دکان کا نام ضروری ہے';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: AppStrings.shopName,
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                  ),
                ),
                const SizedBox(height: 20),
                // Locality field (optional)
                TextFormField(
                  key: const Key('localityField'),
                  controller: _localityController,
                  textDirection: TextDirection.rtl,
                  maxLength: 255,
                  onChanged: (v) =>
                      ref.read(shopSetupProvider.notifier).setLocality(v),
                  decoration: InputDecoration(
                    labelText: '${AppStrings.locality} (اختیاری)',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                  ),
                ),
                if (setupState.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    setupState.error!,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ],
                const Spacer(),
                // Submit button
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _nameController,
                  builder: (context, value, _) {
                    final enabled = value.text.trim().isNotEmpty;
                    return SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        key: const Key('submitButton'),
                        onPressed: enabled ? _onSubmit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          AppStrings.continueText,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Utility — suppress unawaited future lint
void unawaited(Future<void> future) {}
