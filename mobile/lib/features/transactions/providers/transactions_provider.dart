import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/event_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../repositories/event_repository.dart';

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
