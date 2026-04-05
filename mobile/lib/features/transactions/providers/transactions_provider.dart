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

// Temporary device ID provider — STORY-013 will replace with real device_info
final deviceIdProvider = Provider<String>((ref) => 'device-001');
final actorLabelProvider = Provider<String>((ref) => 'Main phone');

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
// ---------------------------------------------------------------------------

final customerBalanceProvider =
    FutureProvider.family<int, String>((ref, customerId) async {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.computeBalance(customerId, PartyType.customer);
});

// ---------------------------------------------------------------------------
// Events stream provider — StreamProvider.family
// Watches all events for a customer ordered by deviceTimestamp DESC.
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
