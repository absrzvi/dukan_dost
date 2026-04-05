import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/database_provider.dart';
import '../repositories/shop_repository.dart';

// ---------------------------------------------------------------------------
// Shop repository provider
// ---------------------------------------------------------------------------

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(appDatabaseProvider);
  return ShopRepository(dio, db);
});

// ---------------------------------------------------------------------------
// Step tracker: 0=shop_setup, 1=contact_import, 2=walkthrough
// ---------------------------------------------------------------------------

final onboardingStepProvider = StateProvider<int>((ref) => 0);

// ---------------------------------------------------------------------------
// Shop setup form state
// ---------------------------------------------------------------------------

class ShopSetupState {
  final String name;
  final String locality;
  final bool isSubmitting;
  final String? error;

  const ShopSetupState({
    this.name = '',
    this.locality = '',
    this.isSubmitting = false,
    this.error,
  });

  ShopSetupState copyWith({
    String? name,
    String? locality,
    bool? isSubmitting,
    String? error,
  }) {
    return ShopSetupState(
      name: name ?? this.name,
      locality: locality ?? this.locality,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

class ShopSetupNotifier extends StateNotifier<ShopSetupState> {
  ShopSetupNotifier() : super(const ShopSetupState());

  void setName(String value) => state = state.copyWith(name: value);
  void setLocality(String value) => state = state.copyWith(locality: value);

  bool get canSubmit => state.name.trim().isNotEmpty && !state.isSubmitting;
}

final shopSetupProvider =
    StateNotifierProvider<ShopSetupNotifier, ShopSetupState>(
  (ref) => ShopSetupNotifier(),
);

// ---------------------------------------------------------------------------
// Contact import — fetches device contacts
// ---------------------------------------------------------------------------

final contactImportProvider = FutureProvider.autoDispose<List<Contact>>((ref) async {
  // Request permission before fetching
  final granted = await FlutterContacts.requestPermission(readonly: true);
  if (!granted) return [];
  return FlutterContacts.getContacts(withProperties: true);
});
