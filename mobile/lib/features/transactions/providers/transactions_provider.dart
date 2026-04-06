import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/event_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../repositories/event_repository.dart';

// ---------------------------------------------------------------------------
// Current shop ID provider — reads the first shop from the local Shops table.
// ---------------------------------------------------------------------------

final currentShopIdProvider = FutureProvider<String?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final shops = await db.select(db.shops).get();
  if (shops.isEmpty) return null;
  if (shops.length > 1) {
    // TODO: enforce single-shop constraint at registration time (STORY-005)
    // ignore: avoid_print
    print('WARNING: multiple shops found (${shops.length}), using first');
  }
  return shops.first.id;
});

// ---------------------------------------------------------------------------
// Device ID provider — reads real Android device ID via device_info_plus.
// Falls back to a UUID stored in SharedPreferences on first run (not implemented
// here) — for now returns the Android ID which is stable per device per app.
// ---------------------------------------------------------------------------

final deviceInfoProvider = FutureProvider<AndroidDeviceInfo?>((ref) async {
  if (!defaultTargetPlatform.toString().contains('android')) return null;
  final plugin = DeviceInfoPlugin();
  return plugin.androidInfo;
});

final deviceIdProvider = Provider<String>((ref) {
  final info = ref.watch(deviceInfoProvider);
  return info.when(
    data: (android) => android?.id ?? 'unknown-${DateTime.now().millisecondsSinceEpoch}',
    loading: () => 'loading',
    error: (_, __) => 'error-device',
  );
});

final actorLabelProvider = Provider<String>((ref) {
  final info = ref.watch(deviceInfoProvider);
  return info.when(
    data: (android) => android != null
        ? '${android.brand} ${android.model}'
        : 'Unknown device',
    loading: () => 'Unknown device',
    error: (_, __) => 'Unknown device',
  );
});

// ---------------------------------------------------------------------------
// EventRepository provider
// ---------------------------------------------------------------------------

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return EventRepository(database: db);
});

// ---------------------------------------------------------------------------
// Balance provider — FutureProvider.family
// Returns the computed balance (int paisa) for a customer.
// TODO: migrate to autoDispose (MINOR-2 / STORY-010)
// ---------------------------------------------------------------------------

final customerBalanceProvider =
    FutureProvider.family<int, String>((ref, customerId) async {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.computeBalance(customerId, PartyType.customer);
});

// ---------------------------------------------------------------------------
// Events stream provider — StreamProvider.family
// Watches all events for a customer ordered by deviceTimestamp DESC.
// TODO: migrate to autoDispose (MINOR-2 / STORY-010)
// ---------------------------------------------------------------------------

final customerEventsProvider =
    StreamProvider.family<List<Event>, String>((ref, customerId) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchEvents(customerId, PartyType.customer);
});

// ---------------------------------------------------------------------------
// Customer events stream provider — autoDispose family (STORY-010)
// Watches events for a customer in ASC order (oldest first) for chat thread.
// ---------------------------------------------------------------------------

final customerEventsStreamProvider =
    StreamProvider.autoDispose.family<List<Event>, String>(
        (ref, customerId) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchEvents(customerId, PartyType.customer);
});

// ---------------------------------------------------------------------------
// Supplier balance provider
// ---------------------------------------------------------------------------

final supplierBalanceProvider =
    FutureProvider.family<int, String>((ref, supplierId) async {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.computeBalance(supplierId, PartyType.supplier);
});

// ---------------------------------------------------------------------------
// Supplier events stream provider
// ---------------------------------------------------------------------------

final supplierEventsProvider =
    StreamProvider.family<List<Event>, String>((ref, supplierId) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchEvents(supplierId, PartyType.supplier);
});
